/*******************************************************************
 * rpisense.h
 *
 * Copyright (c) 2020 HEIG-VD, REDS Institute
 *******************************************************************/


#ifndef RPISENSE_H
#define RPISENSE_H

#include <linux/types.h>
#include <linux/platform_device.h>
#include <linux/mfd/rpisense/core.h>

typedef void(*joystick_handler_t)(struct platform_device *pdev, int key);

#define UP      0x04
#define DOWN    0x01
#define RIGHT   0x02
#define LEFT    0x10
#define CENTER  0x08

/* 8 (row) * 8 (column) * 3 (colors) + 1 (first byte needed blank) */
#define SIZE_FB 193

/* Data used by rpisense for internal handling */
struct rpisense_data {
	joystick_handler_t joystick_handler;
	struct platform_device *pdev;
	struct task_struct *joystick_thread;
	struct rpisense *rpisense;
	unsigned char matrix[SIZE_FB];
};

/**
 * rpisense_init - Intialize the rpisense_data structure and start the
 * thread for switch handling.
 *
 * @param sense_data Pointer to a pre allocated rpisense_data structure.
 *
 * @return 0 on success, a negative errno if an error occured.
 */
int rpisense_init(struct rpisense_data *sense_data);

/**
 * rpisense_remove - Clear everything that has been initialize for the
 * rpisense handling.
 *
 * @param sense_data Pointer to the rpisense_data structure.
 */
void rpisense_remove(struct rpisense_data *sense_data);

/**
 * display_led - Light on or off a given LED on the sense-hat.
 *
 * @param sense_data Pointer to the rpisense_data structure.
 * @param led_nr Number of the LED to modify.
 * @param on true to light on the LED, false to turn it off.
 */
void rpisense_display_led(struct rpisense_data *sense_data, int led_nr,
			  bool on);

/**
 * rpisense_joystick_handler_register - Setup joystick handler called
 * on presses.
 *
 * @param sense_data Pointer to the rpisense_data structure.
 * @param pdev Pointer to the platform device which will be passed to
 *             the handler.
 * @param joystick_handler Callback function used on joystick presses.
 */
int rpisense_joystick_handler_register(struct rpisense_data *sense_data,
				       struct platform_device *pdev,
				       joystick_handler_t joystick_handler);

#endif /* RPISENSE_H */
