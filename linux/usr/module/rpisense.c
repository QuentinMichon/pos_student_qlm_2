/*******************************************************************
 * rpisense.c
 *
 * Copyright (c) 2020 HEIG-VD, REDS Institute
 *******************************************************************/

#include <linux/i2c.h>
#include <linux/delay.h>
#include <linux/kthread.h>

#include <linux/platform_device.h>

#include "rpisense.h"

#define LED_ADDR 0x46
#define JOYSTICK_SUB_ADDR 0xF2

#define MR(row, col) (((row) * NB_ROW_COL * 3) + (col) + 1)
#define MG(row, col) (((row) * NB_ROW_COL * 3) + (col) + 8 + 1)
#define MB(row, col) (((row) * NB_ROW_COL * 3) + (col) + 16 + 1)

#define MEM_R(mem, row, col) (((mem)[(row * 8) + col] >> 11) & 0x1f)
#define MEM_G(mem, row, col) (((mem)[(row * 8) + col] >> 6) & 0x1f)
#define MEM_B(mem, row, col) (((mem)[(row * 8) + col]) & 0x1f)

#define NB_ROW_COL 8

/* 5-bit per colour */
#define RED 0xf800
#define GREEN 0x07e0
#define BLUE 0x001f
#define GRAY 0x3def

#define WHITE 0xffff
#define BLACK 0x0000

/* clang-format off */
static const u16 LEDS_OFF[NB_ROW_COL * NB_ROW_COL] = {
	BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
	BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
	BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
	BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
	BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
	BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
	BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
	BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
};

static const u16 LEDS[][NB_ROW_COL * NB_ROW_COL] = {
	{
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLUE,  BLUE,  BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLUE,  BLUE,  BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
	},
	{
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, WHITE, WHITE, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, WHITE, WHITE, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
	},
	{
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, GREEN, GREEN, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, GREEN, GREEN, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
	},
	{
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, GRAY,  GRAY,  BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, GRAY,  GRAY,  BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
	},
	{
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, RED,   RED,   BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, RED,   RED,   BLACK, BLACK, BLACK,
		BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK, BLACK,
	}
};
/* clang-format on */

/*
 * Polling the joystick event
 */
static int joystick_poll(void *args)
{
	int ret = 0;
	int prev_key = 0;
	struct rpisense_data *priv = args;
	struct rpisense *rpisense = priv->rpisense;

	while (!kthread_should_stop()) {
		ret = i2c_smbus_read_byte_data(rpisense->i2c_client,
					       JOYSTICK_SUB_ADDR);

		if (prev_key != ret) {
			if (priv->joystick_handler && priv->pdev)
				priv->joystick_handler(priv->pdev, ret);
			prev_key = ret;
		}
		msleep(50);
	}

	return 0;
}

int rpisense_joystick_handler_register(struct rpisense_data *sense_data,
				       struct platform_device *pdev,
				       joystick_handler_t joystick_handler)
{
	sense_data->joystick_handler = joystick_handler;
	sense_data->pdev = pdev;

	return 0;
}

void rpisense_display_led(struct rpisense_data *sense_data, int led_nr, bool on)
{
	int i, j;
	const u16 *mem = LEDS[led_nr];
	unsigned char *matrix = sense_data->matrix;
	struct rpisense *rpisense = sense_data->rpisense;

	for (j = 0; j < NB_ROW_COL; j++) {
		for (i = 0; i < NB_ROW_COL; i++) {
			if (on) {
				matrix[MR(j, i)] |= MEM_R(mem, j, i);
				matrix[MG(j, i)] |= MEM_G(mem, j, i);
				matrix[MB(j, i)] |= MEM_B(mem, j, i);
			} else {
				matrix[MR(j, i)] &= ~MEM_R(mem, j, i);
				matrix[MG(j, i)] &= ~MEM_G(mem, j, i);
				matrix[MB(j, i)] &= ~MEM_B(mem, j, i);
			}
		}
	}

	i2c_master_send(rpisense->i2c_client, matrix, SIZE_FB);
}

int rpisense_init(struct rpisense_data *sense_data)
{
	memset(sense_data, 0, sizeof(struct rpisense_data));
	sense_data->rpisense = rpisense_get_dev();
	sense_data->joystick_thread = NULL;

	sense_data->joystick_thread =
		kthread_run(joystick_poll, sense_data, "rpisense-joystick_fn");

	if (IS_ERR(sense_data->joystick_thread)) {
		return -EPERM;
	}

	return 0;
}

void rpisense_remove(struct rpisense_data *sense_data)
{
	if (sense_data->joystick_thread) {
		kthread_stop(sense_data->joystick_thread);
	}
}
