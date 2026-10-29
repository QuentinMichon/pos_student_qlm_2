# Copyright (c) 2025-2026 REDS Institute - HEIG-VD

# VEXT — virtual-extension teaching devices for SO3 (hw/arm/vext/): the vext
# sysbus device + emulation helpers, the cJSON config-file parser under
# hw/arm/vext/json/, and the build wiring (hw/arm/meson.build subdir('vext'),
# hw/arm/Kconfig ARM_VIRT "select VEXT" + the VEXT config stanza). This is
# layered on top of the base qemu recipe as a separate bbappend so the vext
# tree is self-contained and survives a clean fetch+patch build — the pristine
# QEMU 8.2.2 tarball carries none of it, so without this patch a clean build
# would silently drop vext.
#
# Delivered as ONE PATCH PER SOURCE FILE, like the meta-so3, meta-usr and
# meta-linux vext overlays. do_updiff regenerates patches file by file (see
# do_updiff in meta/classes/patch.bbclass); the previous single 0003-vext.patch
# covered fifteen files at once, so none of them was ever regenerable. It also
# separates the teaching concerns — the device model, its emulation helpers, the
# examples and the build wiring are handed out or written independently.
#
# The ../vext hop is not redundant: FILESPATH is expanded lazily, and by then
# THISDIR is the *base recipe's* directory (recipes-qemu/qemu), not this
# bbappend's.

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
FILESPATH:prepend = "${THISDIR}/../vext/files/0001-${PF}:"

require files/0001-${PF}-patches.inc
