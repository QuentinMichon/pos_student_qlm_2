# Copyright (c) 2025-2026 EDGEMTech SA

SUMMARY = "Buildroot rottfs"
DESCRIPTION = "Buildroot is used as rootfs generator"
LICENSE = "GPLv2"

# Release and version
PR = "r0"
PV = "2024.11"

OVERRIDES += ":linux"

inherit rootfs

SRC_URI = "https://buildroot.org/downloads/buildroot-2024.11.tar.gz;protocol=https"
SRC_URI[sha256sum] = "4a601600b846058c2710cfda7d152d5d820b433ff4a4bce65c7eeb49f87e5540"

# defconfig patches and auto-getty patches
FILESPATH:prepend: := "${THISDIR}/files/0001-${PF}:"

require files/0001-${PF}-patches.inc
 
# Where the working directory will be placed in infrabase root dir
IB_TARGET = "${IB_ROOTFS_PATH}/buildroot"

# BR2_DL_DIR: buildroot download cache. Defaults to ${HOME}/.buildroot-dl
# — same persistence pattern as BR2_CCACHE_DIR in the defconfigs. Survives
# workspace cleanups in local builds AND in CI (gitlab-runner $HOME is
# stable), saves ~hundreds of MB of tarball re-downloads. Override via
# env or local.conf if a different location is needed (e.g. multi-user
# host where each user wants their own cache).
IB_BUILDROOT_DL_DIR ?= "${HOME}/.buildroot-dl"

do_configure () {
	cd ${IB_TARGET}

	if [ ! -f ${IB_TARGET}/configs/${IB_PLATFORM}_defconfig ]; then
		bbfatal "${IB_PLATFORM}_defconfig is missing in buildroot/configs ..."
	fi

	mkdir -p "${IB_BUILDROOT_DL_DIR}"
	make O=${IB_ROOTFS_PATH} BR2_DL_DIR="${IB_BUILDROOT_DL_DIR}" ${IB_PLATFORM}_defconfig
}

do_build[nostamp] = "1"

# post_image.sh writes rootfs.cpio into ${IB_ROOTFS_PATH}/board/${IB_PLATFORM},
# which is the board working copy + symlink set up by rootfs-linux:do_attach_
# infrabase under tmp/work. Make sure that copy exists before we build,
# otherwise post_image.sh has nowhere to deposit rootfs.cpio on a fresh tree.
# (buildroot here is the linux rootfs generator only — OVERRIDES += ":linux".)

do_build[depends] += "rootfs-linux:do_attach_infrabase"

# Content-hash guard, same pattern as bsp-linux:do_prepare_initrd.
#
# The task is nostamp — it must stay that way, because bitbake cannot see what
# buildroot consumes (the overlay tree, the defconfig, the patched source). But
# `make` is NOT free when nothing changed: buildroot has no "up to date" fast
# path for target-finalize and the image steps, so every single build re-copies
# the whole target/ tree, recreates every systemd symlink and regenerates
# rootfs.cpio. Measured at ~14 s of a ~23 s no-op `build.sh bsp-linux`.
#
# Worse than the time, that regeneration OVERWRITES rootfs.cpio, discarding what
# usr-linux:do_deploy injected into it, so the whole mount/inject/repack cycle
# has to run again behind it.
#
# So hash what buildroot actually consumes and skip the make when it is
# unchanged:
#   IB_PLATFORM              a platform switch must always rebuild
#   .config                  the resolved buildroot configuration
#   buildroot.attach.sha256  the source tree manifest maintained by
#                            do_attach_infrabase — one file that stands for the
#                            whole patched buildroot source
#   board/                   the BR2_EXTERNAL tree: overlays, post_image.sh, ...
#                            minus its GENERATED artefacts — rootfs.cpio, the
#                            gzipped initrd, their guard files and the
#                            rootfs.cpio.backup that trails every build. Those
#                            are outputs; counting them as inputs makes the
#                            guard invalidate itself on every run.
#
# Content hash rather than mtimes: do_attach_infrabase and the mount/umount
# cycle rewrite files without changing their content.
#
# `build.sh -c buildroot` still forces a full rebuild.

IB_BUILDROOT_GUARD = "${WORKDIR}/buildroot_inputs.sha256"

# The git-tracked board sources, hashed ALONGSIDE the working copy below.
# ${IB_ROOTFS_PATH}/board is only a copy, refreshed from here by
# rootfs-linux:do_attach_infrabase — and that task's ordering relative to this
# one is not guaranteed on every invocation path: `bitbake buildroot -c build`
# was measured hashing a STALE working copy and skipping a make that an overlay
# edit had just made necessary. Nothing rewrites the source, so hashing it makes
# the guard honest whatever the entry point. ../linux is the sibling rootfs
# recipe this one is bound to by OVERRIDES += ":linux" above.
IB_BUILDROOT_SRC_BOARD = "${THISDIR}/../linux/files/board"

# One definition, called before and after the make — writing the pipeline twice
# is how the two copies end up disagreeing.
#
# `find -L`, not `find`: ${IB_ROOTFS_PATH}/board is a SYMLINK to the working
# copy under tmp/work (rootfs-linux:do_attach_infrabase), and find does not
# descend into a symlinked directory. Without -L this hashes nothing at all and
# the guard silently never invalidates on an overlay change.

# Every element below ends in "|| echo <marker>". bitbake runs shell tasks under
# `set -e`, so ONE failing command — a cat on a file that does not exist yet, a
# find on a tree not created yet — aborts the whole { } group, and the hash
# silently degenerates into a constant that no overlay edit can change: the
# guard then skips forever. Measured on edgem1, where linux/rootfs/
# buildroot.attach.sha256 is absent: src and board trees changed, the total did
# not. The marker also keeps "missing" distinguishable from "empty".

buildroot_hash_tree() {
	find -L "$1" -type f \
		! -name '*.cpio' ! -name '*.cpio.gz' ! -name '*.srchash' \
		! -name '*.backup' ! -name '*.sha256' \
		-exec sha256sum {} + 2>/dev/null | sort || echo "no-tree:$1"
}

buildroot_inputs_hash() {
	{ echo "${IB_PLATFORM}"
	  cat "${IB_ROOTFS_PATH}/.config" 2>/dev/null || echo "no-config"
	  cat "${IB_ROOTFS_PATH}/buildroot.attach.sha256" 2>/dev/null || echo "no-manifest"
	  buildroot_hash_tree "${IB_BUILDROOT_SRC_BOARD}"
	  buildroot_hash_tree "${IB_ROOTFS_PATH}/board"
	} | sha256sum | cut -d' ' -f1
}

do_build () {
	bbnote "Building buildroot based rootfs..."

	if [ -f "${IB_BUILDROOT_GUARD}" ] && \
	   [ "$(cat ${IB_BUILDROOT_GUARD})" = "$(buildroot_inputs_hash)" ] && \
	   [ -f "${IB_ROOTFS_PATH}/board/${IB_PLATFORM}/rootfs.cpio" ]; then
		bbplain "buildroot: inputs unchanged, rootfs.cpio present — skipping (build.sh -c buildroot forces it)"
		return 0
	fi

	cd ${IB_TARGET}
	make  O=${IB_ROOTFS_PATH} BR2_EXTERNAL_DIRS=.. BR2_DL_DIR="${IB_BUILDROOT_DL_DIR}" --no-print-directory

	# Recorded only after a successful make — a failed build must not be
	# remembered as up to date — and re-hashed rather than reusing the value
	# computed above, since the make may legitimately touch its own inputs
	# (.config normalisation, for one).
	buildroot_inputs_hash > "${IB_BUILDROOT_GUARD}"
}

do_clean[nostamp] = "1"

do_clean () {
	bbnote "Cleaning the entire rootfs..."
	
	rm -rf ${IB_ROOTFS_PATH}/build
	rm -rf ${IB_ROOTFS_PATH}/target
	rm -rf ${IB_ROOTFS_PATH}/host
	rm -rf ${IB_ROOTFS_PATH}/scripts
	rm -rf ${IB_ROOTFS_PATH}/images
	rm -rf ${IB_ROOTFS_PATH}/staging

	rm -f ${TMPDIR}/stamps/buildroot*

	# The do_build guard must go with the output it vouches for: this task
	# does NOT delete board/<plat>/rootfs.cpio, so a surviving guard would
	# make the next build skip a make that has everything left to redo.
	rm -f ${IB_BUILDROOT_GUARD}
}
addtask do_clean


