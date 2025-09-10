/*
 * Copyright (C) 2013-2014 Romain Bornet <romain.bornet@heig-vd.ch>
 * Copyright (C) 2016-2020 Daniel Rossier <daniel.rossier@heig-vd.ch>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 */

#include "qemu/osdep.h"
#include <stddef.h>
#include <errno.h>

#include "sysemu/sysemu.h"

#include "vext.h"

#include "qemu/thread.h"
#include "qemu/queue.h"

#include "qemu/sockets.h"

#include "vext_emul.h"

#include "json/cjson.h"

#include "qemu/main-loop.h"

static void * __opaque = NULL;

typedef struct vextPacket {
	QSIMPLEQ_ENTRY(vextPacket)
	entry;
	cJSON * packet;
} vextPacket;

typedef struct vextEmulState {
	int sock; /* Socket to command server */

	QSIMPLEQ_HEAD(cmd_list, vextPacket)
	cmd_list; /* Outgoing packets (commands) */
	QSIMPLEQ_HEAD(event_list, vextPacket)
	event_list; /* Ingoing packets (events) */

	QemuMutex cmd_mutex; /* Condition variable and associated mutex */
	QemuCond cmd_cond;
	QemuMutex connect_mutex; /* Mutex for connection handling */

	QemuThread eventThreadId; /* Command thread sending commands to the GUI */
	QemuThread cmdThreadId; /* Command thread sending commands to the GUI */

	int thread_terminate; /* Flag to indicate that the the threads should terminate */

} vextEmulState;

static vextEmulState vext_state;

/*
 * This function adds the cJSON pointer in the queue
 */
void *vext_cmd_post(cJSON *packet) {
	if (vext_state.thread_terminate) {
		cJSON_Delete(packet);
		return NULL;
	}

	vextPacket *cmd;

	DBG("%s\n", __func__);

	cmd = g_malloc(sizeof(vextPacket));
	cmd->packet = packet;

	qemu_mutex_lock(&vext_state.cmd_mutex);

	DBG("%s Inserting into queue...\n", __FUNCTION__);
	QSIMPLEQ_INSERT_TAIL(&(vext_state.cmd_list), cmd, entry);
	qemu_cond_signal(&vext_state.cmd_cond);
	DBG("%s ...done\n", __FUNCTION__);

	qemu_mutex_unlock(&vext_state.cmd_mutex);

	return NULL;
}

static void vext_try_connect(void) {
	char host[255];
	snprintf(host, 255, "%s:%d", TCP_HOSTNAME, TCP_PORT);

	qemu_mutex_lock(&vext_state.connect_mutex);

	if (vext_state.sock >= 0) {
		/* Already connected */
		qemu_mutex_unlock(&vext_state.connect_mutex);
		return;
	}

	printf("%s: trying to connect to Sense-HAT server...\n", __func__);
	while (vext_state.sock < 0 && !vext_state.thread_terminate) {
		/* Try to connect */
		vext_state.sock = inet_connect(host, NULL);

		if (vext_state.sock < 0) {
			sleep(CONNECT_WAIT);
		}
	}
	printf("%s: connected to Sense-HAT server!\n", __func__);

	qemu_mutex_unlock(&vext_state.connect_mutex);
}

/*
 * This loop empties the queue as fast as it can, sending the stringified
 * JSON through the socket.
 */
static void *vext_emul_cmd_process(void *arg) {
	int ret;
	vextEmulState *vext = arg;
	vextPacket *cmd;
	char *rendered;
	unsigned int len;

	while (!vext->thread_terminate) {
		/* Wait on command to process */
		qemu_mutex_lock(&vext->cmd_mutex);
		qemu_cond_wait(&vext->cmd_cond, &vext->cmd_mutex);
		qemu_mutex_unlock(&vext->cmd_mutex);

		if (vext->thread_terminate)
			break;

		/* while not empty */
		while (!vext->thread_terminate && !QSIMPLEQ_EMPTY(&vext->cmd_list)) {
			qemu_mutex_lock(&vext->cmd_mutex);
			cmd = QSIMPLEQ_FIRST(&vext->cmd_list);
			QSIMPLEQ_REMOVE_HEAD(&vext->cmd_list, entry);

			rendered = cJSON_Print(cmd->packet);
			cJSON_Minify(rendered);
			len = strlen(rendered);

			rendered[len] = '\n';

			if (vext->sock >= 0) {
				ret = write(vext->sock, rendered, len + 1);
				if (ret <= 0) {
					fprintf(stderr,
						"%s: Write error on socket.\n",
						__func__);
					close(vext->sock);
					vext->sock = -1;
				}
			} else {
				DBG("%s: Not connected, cannot send command.\n",
				    __func__);
			}
			free(rendered);

			qemu_mutex_unlock(&vext->cmd_mutex);
			cJSON_Delete(cmd->packet);
			g_free(cmd);
		}
	}

	/* Empty queue on exit */
	while (!QSIMPLEQ_EMPTY(&vext->cmd_list)) {
		qemu_mutex_lock(&vext->cmd_mutex);

		cmd = QSIMPLEQ_FIRST(&vext->cmd_list);
		cJSON_Delete(cmd->packet);
		g_free(cmd);

		qemu_mutex_unlock(&vext->cmd_mutex);
	}

	/* Close connection to server here ... */
	DBG("%s thread exits!\n", __FUNCTION__);
	return NULL;

}

/*
 * This loop receives and parses data from the socket, to cJSON objects.
 * Then the right driver callback is called.
 */
static void *vext_emul_event_handle(void *arg) {
	char inBuffer[1024]; /* Must be big enough to contain a least one json object */
	int readBytes;
	cJSON *root, *devnode;

	int alreadyReadBytes = 0;
	vextEmulState *vext = arg;

	vext_try_connect();

	while (!vext->thread_terminate) {
		if (vext->sock < 0) {
			vext_try_connect();
			continue;
		}

		/* Read from the socket. */
		readBytes = read(vext->sock, inBuffer + alreadyReadBytes, sizeof(inBuffer) - alreadyReadBytes);

		if (readBytes < 0) {
			if (errno == EAGAIN || errno == EWOULDBLOCK) {
				/* No data available, try again later */
				continue;
			}

			/* Connection error */
			close(vext->sock);
			vext->sock = -1;
			alreadyReadBytes = 0;
			continue;
		}

		DBG("%s: read %d \n", __FUNCTION__, readBytes);

		if (readBytes == 0) {
			/* Connection closed by the other side */
			close(vext->sock);
			vext->sock = -1;
			alreadyReadBytes = 0;
			continue;
		}
		/* If something has been read. */
		if (readBytes > 0)
			alreadyReadBytes += readBytes;

		/* If something is present in the FIFO  */
		if (alreadyReadBytes) {
			/* For each newLine delimited string */
			while (1) {
				char *newLine = memchr(inBuffer, '\n', alreadyReadBytes);

				if (!newLine) {
					/* If FIFO is full, but there is no newline, something went wrong. We discard the whole FIFO. */
					if (alreadyReadBytes == sizeof(inBuffer))
						alreadyReadBytes = 0;

					break;
				}

				/* Replace newline by 0, so cJSON parses only one object */
				*newLine = '\0';

				root = cJSON_Parse(inBuffer);

				DBG("%s: cJSON_Parse done \n", __FUNCTION__);

				if (root) {
					devnode = cJSON_GetObjectItem(root, "device");

					if (strcmp(devnode->valuestring, DEV_SWITCH) == 0)  {
						qemu_mutex_lock_iothread();
						vext_process_switch(__opaque, root);
						qemu_mutex_unlock_iothread();
					} else
						DBG("%s: Error, unknow device: %s \n", __func__, devnode->valuestring);

					cJSON_Delete(root);

				} else
					DBG("%s: Error, not valid JSON: %s \n", __func__, inBuffer);

				/*
				 * Update alreadyReadBytes. The +1 is for the discarded null char
				 */
				alreadyReadBytes -= newLine - inBuffer + 1;

				/* Move the fifo:
				 * - Destination in inBuffer, base of the FIFO
				 * - Copy from newLine+1, so we discard the newLine
				 * - Copy the rest of the FIFO (alreadyReadBytes is up to date)
				 */
				memmove(inBuffer, newLine + 1, alreadyReadBytes);
			}
		}
	}
	DBG("%s thread exits!\n", __FUNCTION__);
	return NULL;
}

int vext_emul_init(Object *obj) {
	DBG("%s\n", __func__);

	__opaque = SYS_BUS_DEVICE(obj);

	QSIMPLEQ_INIT(&vext_state.event_list);
	QSIMPLEQ_INIT(&vext_state.cmd_list);

	qemu_mutex_init(&vext_state.cmd_mutex);
	qemu_cond_init(&vext_state.cmd_cond);
	qemu_mutex_init(&vext_state.connect_mutex);

	vext_state.thread_terminate = 0;
	vext_state.sock = -1;

	/* Thread for output commands */
	qemu_thread_create(&vext_state.cmdThreadId, "cmd_process",
			vext_emul_cmd_process, &vext_state, QEMU_THREAD_JOINABLE);

	/* Thread for input events */
	qemu_thread_create(&vext_state.eventThreadId, "event_handle",
			vext_emul_event_handle, &vext_state,
			QEMU_THREAD_JOINABLE);

	return 0;
}

int vext_emul_exit(void) {
	/* Stop the cmd processing thread */
	vext_state.thread_terminate = 1;

	qemu_cond_signal(&vext_state.cmd_cond);
	qemu_thread_join(&vext_state.cmdThreadId);
	qemu_thread_join(&vext_state.eventThreadId);

	close(vext_state.sock);

	return 0;
}
