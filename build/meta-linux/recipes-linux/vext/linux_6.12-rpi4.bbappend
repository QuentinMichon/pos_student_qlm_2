# Copyright (c) 2025-2026 REDS Institute - HEIG-VD

# VEXT on the Raspberry Pi kernel fork (rpi4 / rpi4_64): the I2C drivers in
# the defconfig and the device tree node of the teaching device (lab07). i2c1
# and the RAM size are set by the base series. The driver and the applications
# are user space, delivered by the meta-usr vext bbappend.
#
# Same lazy-FILESPATH idiom as linux_6.12.bbappend next door.

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
FILESPATH:prepend = "${THISDIR}/../vext/files/0001-${PF}:"

require files/0001-${PF}-patches.inc
