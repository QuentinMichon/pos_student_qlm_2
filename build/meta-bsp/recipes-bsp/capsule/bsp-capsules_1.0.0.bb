# Copyright (c) 2025-2026 EDGEMTech SA

SUMMARY = "SO3 capsule Deployment"
DESCRIPTION = "SO3 capsules are aimed to run with Linux as guest on top of the AVZ hypervisor."

LICENSE = "GPLv2"

# Version and revision
PV = "1.0.0"
PR = "r0"

inherit filesystem
inherit uboot
inherit bsp

# Capsules reuse the SO3 ITS templates (e.g. <plat>_capsule.its)
IB_ITS_SRC = "${THISDIR}/../so3/files/its"

# :append (not +=) so no space is inserted before ":so3" — otherwise the
# preceding CPU token parses as "arm "/"aarch64 " and :<cpu> overrides
# stop matching. See usr-so3_1.0.bb for the full rationale.
OVERRIDES:append = ":so3"

do_configure[noexec] = "1"
do_attach_infrabase[noexec] = "1"

# Building all components

do_build[depends] = "usr-so3:do_build" 

do_build () {
	bbplain "Everything built OK ..."
}
addtask do_build

####################### Recipe to deploy everything

def __do_platform_deploy(d):

    import os

    capsule_path = d.getVar('IB_FILESYSTEM_PATH') + "/p2/mnt/capsules/image"
    itb_path = d.getVar('IB_ITB_PATH') + "/" + d.getVar('IB_TARGET_ITS') + ".itb"

    if not os.path.isfile(itb_path):
        bb.fatal(itb_path + " is missing ...")

    # The p2 rootfs is extracted as root, so any write into it must be
    # escalated (bitbake itself runs unprivileged) and must fail loudly.
    utils_sudo(['mkdir', '-p', capsule_path], check=True)
    utils_sudo(['cp', itb_path, capsule_path], check=True)

do_itb[nostamp] = "1"
do_itb[depends] = "usr-so3:do_deploy"
do_itb () {

	# ITS rendered into IB_ITB_PATH by the shared do_render_its (before do_itb).
	#
	# Two failures, two messages — same check as bsp-so3_1.0.0.bb, which this
	# recipe shares its ITS templates and its :so3 override scope with. An
	# unset IB_TARGET_ITS used to report the capsule name as an empty string.
	# Plain $its_avail, no braces: bitbake expands every ${...} at parse time,
	# so a braced shell variable would go through its expander first. The
	# <plat>${IB_GUEST_SUFFIX} template is dropped from the list: it is the
	# guest ITB auto-derived from a *_avz selection, never something to put in
	# local.conf.
	its_avail=$(cd "${IB_ITS_SRC}" 2>/dev/null && \
		ls -1 ${IB_PLATFORM}.its ${IB_PLATFORM}_*.its 2>/dev/null | \
		sed -e 's/\.its$//' -e '/${IB_GUEST_SUFFIX}$/d' | \
		tr '\n' ' ' | sed 's/ *$//')
	[ -n "$its_avail" ] || its_avail="none for this platform"

	if [ -z "${IB_TARGET_ITS}" ]; then
		bbfatal "No ITS selected for platform '${IB_PLATFORM}': set" \
			"IB_TARGET_ITS:so3:${IB_PLATFORM} in build/conf/local.conf" \
			"— a capsule build expects the ${IB_PLATFORM}_capsule template" \
			"(available: $its_avail)"
	fi

	if [ ! -f ${IB_ITB_PATH}/${IB_TARGET_ITS}.its ]; then
		bbfatal "ITS '${IB_TARGET_ITS}' selected by" \
			"IB_TARGET_ITS:so3:${IB_PLATFORM} has no template" \
			"${IB_ITS_SRC}/${IB_TARGET_ITS}.its" \
			"(available: $its_avail)"
	fi
	mkimage -f ${IB_ITB_PATH}/${IB_TARGET_ITS}.its ${IB_ITB_PATH}/${IB_TARGET_ITS}.itb
	
}

do_deploy[depends] = "usr-so3:do_deploy"
 
do_deploy[nostamp] = "1"
python do_deploy() {
    
    bb.plain("Deploy SO3 image and U-boot")

    __do_deploy_boot(d);
}

addtask do_itb before do_deploy
addtask do_deploy

do_deploy_boot[nostamp] = "1"
python do_deploy_boot() {

    bb.plain("Deploy SO3 boot (u-boot, itb)")

    __do_deploy_boot(d)
}
addtask do_itb before do_deploy_boot
addtask do_deploy_boot

do_clean[depends] = "usr-so3:do_clean so3:do_clean uboot:do_clean"
do_clean[nostamp] = "1"
do_clean () {
	rm -f ${TMPDIR}/stamps/bsp-so3*
}
addtask do_clean

 
 

