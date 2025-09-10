#!/usr/bin/env python3

import socket
import json
import numpy as np
import subprocess
import io
import os
import threading
import signal
import sys
import fcntl

from sense_emu import SenseHat

HOST = '0.0.0.0'  # All addresses
PORT = 4442        # Port to listen for qemu client

# Draw the foreground (fg) into a numpy array
Rd = (255, 0, 0)
Gn = (0, 255, 0)
Bl = (0, 0, 255)
Gy = (128, 128, 128)
Wh = (255, 255, 255)
__ = (0, 0, 0)

ledsoff =[
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    ]

leds = [
    [
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
     __, __, __, __, __, __, __, __,
    __, __, __, Bl, Bl, __, __, __,
    __, __, __, Bl, Bl, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    ],

    [
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, Wh, Wh, __, __, __, __, __,
    __, Wh, Wh, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    ],

   [
    __, __, __, __, __, __, __, __,
    __, __, __, Gn, Gn, __, __, __,
    __, __, __, Gn, Gn, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    ],

   [
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, Gy, Gy, __,
    __, __, __, __, __, Gy, Gy, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    ],

   [
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, __, __, __, __, __,
    __, __, __, Rd, Rd, __, __, __,
    __, __, __, Rd, Rd, __, __, __,
    __, __, __, __, __, __, __, __,
    ]
]

def display(hat, selection):
    # Draw the background (bg) selection box into another numpy array
    # Construct final pixels from bg array with non-transparent elements of
    # the menu array
    current = hat.get_pixels()

    m1 = np.array(current)
    m2 = np.array(leds[selection])

    result = m1 | m2

    hat.set_pixels(result)

devnull=io.open(os.devnull, 'r+b')
setpgrp = None

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

try:
    sock.bind((HOST, PORT))
except socket.error as msg:
        print('Bind failed. Error Code : ' + str(msg[0]) + ' Message ' + msg[1])
        sys.exit()
print('Socket bind complete')

#Start listening on socket
sock.listen(1)
print('Socket now listening')
conn = None

subprocess.Popen(['sense_emu_gui'], preexec_fn=setpgrp,
                         stdin=devnull, stdout=devnull, stderr=devnull,
                         close_fds=True)

sense = SenseHat()
sense.set_pixels(ledsoff)

# Prepare to process joystick events

def stick_event(event):
    #print("action "+event.action)
    obj = None
    if event.action == "pressed":
        if event.direction == "middle":
            obj = json.dumps({'device':'switch', 'status':1})
        if event.direction == "left":
            obj = json.dumps({'device':'switch', 'status':2})
        if event.direction == "up":
            obj = json.dumps({'device':'switch', 'status':4})
        if event.direction == "right":
            obj = json.dumps({'device':'switch', 'status':8})
        if event.direction == "down":
            obj = json.dumps({'device':'switch', 'status':16})

    if event.action == "released":
        obj = json.dumps({'device':'switch', 'status':0})

    # Send to qemu
    if (obj != None):
        if conn == None:
            print("[sense-hat GUI] No connection to client, cannot send event")
            return
        #print(obj)
        conn.sendall(bytes(obj+"\n", 'utf-8'))

# Switch nr 0
sense.stick.direction_middle = stick_event

# Switch nr 1
sense.stick.direction_left = stick_event

# Switch nr 2
sense.stick.direction_up = stick_event

# Switch nr 3
sense.stick.direction_right = stick_event

# Switch nr 4
sense.stick.direction_down = stick_event

def get_status(fileno):
    fl = fcntl.fcntl(fileno, fcntl.F_GETFL)
    if (fl & os.O_NONBLOCK) == os.O_NONBLOCK:
        return "nonblocking"
    else:
        return "blocking"

def set_nonblocking(fileno):
    fl = fcntl.fcntl(fileno, fcntl.F_GETFL)
    return fcntl.fcntl(fileno, fcntl.F_SETFL, fl | os.O_NONBLOCK)

def set_blocking(fileno):
    if get_status(fileno) == "nonblocking":
        fl = fcntl.fcntl(fileno, fcntl.F_GETFL)
        return fcntl.fcntl(fileno, fcntl.F_SETFL, fl - os.O_NONBLOCK)
    else:
        return 0

stdout = sys.stdout.fileno()
set_blocking(stdout)

#wait to accept a connection - blocking call
conn, addr = sock.accept()
print('Connected with ' + addr[0] + ':' + str(addr[1]))

while True:
    data = conn.recv(1024)
    if not data:
        print("[sense-hat GUI] Connection closed by client")
        conn.close()
        conn = None
        conn, addr = sock.accept()
        print('Connected with ' + addr[0] + ':' + str(addr[1]))
        continue

    packets = data.split()
    for s in packets:
        print("[sense-hat GUI] Got JSON packet" + str(s))
        obj = json.loads(s)
        if obj["device"] == "led":
            # Reset all LEDs
            sense.set_pixels(ledsoff)
            val = obj["value"]

            print("[sense-hat GUI] device LED detected (value "+str(val)+")")

            for led in range(5):
                if (val & (1 << led) != 0):
                    display(sense, led)
