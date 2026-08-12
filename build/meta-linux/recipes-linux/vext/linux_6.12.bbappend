# Copyright (c) 2025-2026 REDS Institute - HEIG-VD

# VEXT — the device tree node for the teaching device, on the vanilla kernel
# (virt32/virt64). The base recipe ships virt64.dts as a creation patch (a dump
# of the device tree QEMU generates for its virt machine); QEMU knows nothing of
# vext, which is an addition of ours to hw/arm, so nothing puts the node there.
# This bbappend adds it on top — SRC_URI order makes it apply after the base set.
#
# The driver itself (access.c) and the applications are user space, delivered by
# the meta-usr vext bbappend.
#
# The rpi4 kernel is a different tree entirely (raspberrypi/linux, see
# linux_6.12-rpi4.bb) and needs its own node: the Sense HAT path has no MMIO
# device, and only that fork carries the rpisense MFD the driver binds to.

# The ../vext hop is not redundant: FILESPATH is expanded lazily, and by then
# THISDIR is the *base recipe's* directory (recipes-linux/linux), not this
# bbappend's — so a bare ${THISDIR}/files would look under the base recipe and
# the patch would not be found. Same idiom as the meta-usr soo bbappend.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
FILESPATH:prepend = "${THISDIR}/../vext/files/0001-${PF}:"

require files/0001-${PF}-patches.inc
