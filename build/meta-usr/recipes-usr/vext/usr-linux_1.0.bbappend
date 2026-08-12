# Copyright (c) 2025-2026 REDS Institute - HEIG-VD

SUMMARY = "VEXT teaching device — agency user space"
DESCRIPTION = "Kernel module and applications driving the vext device from Linux"
LICENSE = "GPLv2"

# The agency user space is regenerated from a patch set on every build (${S}
# starts empty), so the vext material is delivered the same way: creation
# patches for what is ours, plus two small edits to the base tree.
#
#   src/vext/           display + its CMakeLists (vextctl is a lab06 exercise)
#   src/modules/access.c  the platform driver: it registers the five LEDs with
#                         the LED class (/sys/class/leds/vext_led*) and the
#                         switch as an input device, so the applications talk to
#                         standard kernel interfaces and never to the hardware.
#
# The ../vext hop is not redundant: FILESPATH is expanded lazily, and by then
# THISDIR is the *base recipe's* directory (recipes-usr/linux), not this
# bbappend's. Same idiom as the soo bbappend next door.

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
FILESPATH:prepend = "${THISDIR}/../vext/files/0001-${PF}:"

require files/0001-${PF}-patches.inc

# The base recipe installs its apps one by one (only *.ko is globbed), so ours
# have to be named too — otherwise they build and never reach the rootfs.
do_install_apps:append () {

    usr_do_install_file_root "${IB_TARGET}/build/src/vext/display"
}
