# Copyright (c) 2025-2026 REDS Institute - HEIG-VD

# VEXT — the teaching device this course is built around, layered on top of the
# stock SO3 kernel the base recipe fetches:
#
#   - devices/vext.c and its Kconfig/Makefile wiring (CONFIG_VEXT). The driver
#     has two paths: the QEMU-emulated MMIO device on virt32/virt64, and the
#     real Sense HAT on rpi4/rpi4_64, where the LEDs and the joystick are driven
#     over I2C through rpisense.
#   - the vext nodes in the virt64/rpi4/rpi4_64 device trees, and the defconfig
#     entries that turn the driver (and, on rpi4, I2C/I2C_BSC/RPI_SENSE) on.
#   - uapi/linux/input.h: input_event must be 8 bytes on BOTH sides — the kernel
#     struct carried a leading timeval, so it wrote 24-byte records while user
#     space read 8 and got garbage. usr/lib/linux/input.h is the user-space half.
#   - usr/src/CMakeLists.txt (vextctl itself is written by the student, lab06).
#
# This lives here rather than in the kernel tree on purpose: upstream SO3 knows
# nothing about the course, and must not. Enabling i2c_bsc/rpisense by default
# there would make every rpi4_64 probe a Sense HAT that may not be fitted — they
# are CORE drivers, so they probe before the console and take the kernel down
# silently when the hardware is absent.
#
# Kept as a separate bbappend, like meta-qemu's vext one, so the lab stays
# self-contained and a clean fetch+patch build cannot silently drop it: the
# fetched v6.2.4 tarball carries none of this.
#
# Delivered as ONE PATCH PER SOURCE FILE, like the meta-usr and meta-linux vext
# overlays. Two reasons, beyond readability:
#
#   - do_updiff can only consolidate a file whose patchset holds exactly one
#     patch targeting it (see index_patchset() in meta/classes/patch.bbclass).
#     The previous single 0001-vext.patch covered thirteen files at once, so
#     none of them could ever be regenerated in place.
#   - each file is a separate teaching concern — the driver, the Kconfig entry,
#     the Makefile wiring, the device-tree nodes — and a lab may hand out some
#     while asking students to write the others. That choice is only expressible
#     if the patches are separable.
#
# The ../vext hop is not redundant: FILESPATH is expanded lazily, and by then
# THISDIR is the *base recipe's* directory (recipes-so3/so3), not this
# bbappend's. Same idiom as the meta-usr vext bbappend.

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
FILESPATH:prepend = "${THISDIR}/../vext/files/0001-${PF}:"

require files/0001-${PF}-patches.inc
