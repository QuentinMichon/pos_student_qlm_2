# Copyright (c) 2025-2026 REDS Institute - HEIG-VD

# VEXT on the Raspberry Pi kernel fork (rpi4 / rpi4_64): the device tree node
# for the teaching device, plus i2c1 switched on — this kernel boots with the
# fork-built dtb embedded in the FIT image, so the firmware's dtparam mechanism
# cannot enable the bus. The driver and the applications are user space,
# delivered by the meta-usr vext bbappend.
#
# Same lazy-FILESPATH idiom as linux_6.12.bbappend next door.

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
FILESPATH:prepend = "${THISDIR}/../vext/files/0001-${PF}:"

require files/0001-${PF}-patches.inc
