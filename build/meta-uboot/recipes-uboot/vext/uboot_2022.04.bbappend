# Copyright (c) 2025-2026 REDS Institute - HEIG-VD

# The U-Boot half of the course solutions, recovered from the 2025 tree
# (~/pos/pos_sol.25/u-boot) and split back into the two exercises it had been
# fused into. Kept as a separate overlay, like the meta-so3/meta-usr/meta-linux/
# meta-qemu vext ones, so it is a single directory to leave out of the student
# tree — lab01 and lab04 both ask students to write these files themselves.
#
#   lab01 — cmd/hello.c: a command that prints a message, created from
#           cmd/version.c, plus its cmd/Makefile entry. Nothing else.
#   lab04 — cmd/enable_irq.c: GIC setup, vExt interrupt unmasking and the
#           handler that toggles the LED of the pressed switch. It needs the
#           IRQ path to reach C code, hence the two arch/arm/lib patches:
#           interrupts.c calls handle_irq() from do_irq(), and vectors.S gets
#           a working IRQ entry/exit (proper frame, spsr restore, return via
#           ldmia {sp, lr, pc}^) — the stock U-Boot one does not return.
#
# ADDRESSES: updated for this tree. The 2025 QEMU hardcoded the device at
# 0x20000000 with no interrupt line at all; here it is memmap[VIRT_VEXT] =
# 0x08804000 with irqmap[VIRT_VEXT] = 13, an SPI, so INTID 32 + 13 = 45 (the
# old code unmasked 82). enable_irq.c now derives every GIC register offset
# from VEXT_IRQ instead of open-coding the numbers, so the next move only
# touches the two defines. The GIC bases are unchanged (0x0800_0000 /
# 0x0801_0000) and match what lab04 tells students.
#
# cmd/Makefile is also patched by the base set (0010, for guest_boot), so this
# overlay is a second patch on that file — the one chain do_updiff cannot
# consolidate. Accepted as temporary for these exercises. Both commands share
# that single patch rather than adding one each, which would chain within this
# set too.

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
FILESPATH:prepend = "${THISDIR}/../vext/files/0001-${PF}:"

require files/0001-${PF}-patches.inc
