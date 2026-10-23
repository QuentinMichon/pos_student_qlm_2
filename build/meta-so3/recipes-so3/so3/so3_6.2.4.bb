# Copyright (c) 2025-2026 EDGEMTech SA

SUMMARY = "SO3 kernel"
DESCRIPTION = "Smart Object Oriented Operating System"
LICENSE = "GPLv2"

inherit so3

# Version and revision
PR = "r0"
PV = "6.2.4"

# :append (not +=) so no space is inserted before ":so3" — otherwise the
# preceding CPU token parses as "arm "/"aarch64 " and :<cpu> overrides
# stop matching. See usr-so3_1.0.bb for the full rationale.
OVERRIDES:append = ":so3"

IB_TARGET = "${IB_SO3_PATH}"

# IB_TARGET is the whole so3/ tree, so updiff would also pick up what the build
# leaves in it: the arch marker do_configure writes (.ib_last_arch, also in
# usr/), the usr-so3 CMake build directory (usr/build/) and the rendered
# ITS/ITB (images/). Upstream SO3 has no directory named build or images.
IB_UPDIFF_EXCLUDE = ".ib_last_arch build images"

# SO3 is FETCHED from upstream and pinned to a release tag; the course material
# lives on top of it as a patch set (see recipes-so3/vext), never as edits to
# the kernel itself. That split is what keeps upstream free of anything
# lab-specific, and it means a generic fix found here goes there rather than
# quietly diverging.
#
# A tag, not a branch: a given checkout of this repo must always build the same
# kernel — not something students should have to think about. Bumping is
# deliberate: change SRCREV together with PV and PREFERRED_VERSION_so3.
#
# NB the source comes from git, so local edits under ${IB_SO3_PATH} are not
# built. do_attach_infrabase refuses to overwrite them (so3.attach.sha256
# guard); fold them into the patch set with `bitbake so3 -c updiff` first.
SRC_URI = "git://github.com/smartobjectoriented/so3.git;protocol=https;nobranch=1"
SRCREV = "2e9555f0e1bbc0df0bb902601885dbde5bcfb04c"

# The stamps of this build system carry no signature hash, so bumping SRCREV
# above, or changing the course patch set, would NOT re-trigger the chain on
# its own: unpack/patch/attach would be skipped and the tree would silently stay
# stale. Key the stamps on them instead: stamp-extra-info is appended to the
# stamp file name, so when the value changes the stamp is "missing", the task
# re-runs, and every later task of the recipe follows (its stamp is now older).
#
#   do_fetch  keyed on SRCREV          -> new upstream revision
#   do_patch  keyed on the patch set   -> course update, or a do_updiff
#
# Not do_fetch[nostamp]: that re-ran fetch..attach on EVERY build, so
# do_attach_infrabase recopied so3/ each time (full rebuild, new files moved to
# so3.back) and its dirty-tree guard refused any build until the edit had been
# updiff'ed. Same mechanism as the avz recipe.
do_fetch[stamp-extra-info] = "${SRCREV}"
do_fetch[prefuncs] += "ib_drop_stale_stamps"
do_patch[prefuncs] += "ib_drop_stale_stamps"

python () {
    d.setVarFlag('do_patch', 'stamp-extra-info', ib_patchset_digest(d))
}

python do_handle_fetch_git() {

    import os
    import subprocess

    # The upstream repo nests its trees under <root>/so3 ({so3, usr, rootfs}),
    # and that subtree is exactly what maps onto IB_SO3_PATH. The rest of the
    # repo (its own build/, scripts/, doc/) is not ours to take — this one has
    # its own. Hence copying from gitdir/so3 rather than gitdir.

    gitdir = os.path.join(d.getVar('WORKDIR'), 'git')
    dst_dir = d.getVar('S')

    # -type l as well as -type f: scripts/dtc/include-prefixes is a directory of
    # symlinks into arch/*/boot/dts, and matching only regular files would drop
    # them silently — the tree would then differ from the tag it claims to be,
    # and any DTS reaching for <dt-bindings/...> would fail to build. cp -r does
    # not dereference, so they are recreated as links.
    cmd = f"find . -not -path '*/.git/*' -and \( -type f -or -type l -or -type d -empty \) -exec cp -r --parents -t {dst_dir} {{}} +"
    subprocess.run(cmd, shell=True, check=True, cwd=os.path.join(gitdir, "so3"))
}

do_configure[nostamp] = "1"
do_configure () {
	cd ${IB_SO3_PATH}/so3

	# The kernel is built in place, so a stale .config/objects from the
	# other architecture (virt64<->virt32, i.e. aarch64<->arm) would
	# otherwise survive and produce a wrong-arch kernel. Track the last
	# built arch in a marker file and distclean only when it changes —
	# so same-arch rebuilds stay incremental.
	_arch_marker=".ib_last_arch"
	if [ -f "$_arch_marker" ] && [ "$(cat $_arch_marker)" != "${IB_PLAT_CPU}" ]; then
		echo "SO3 arch changed ($(cat $_arch_marker) -> ${IB_PLAT_CPU}); running make distclean"
		make distclean
	fi

	make ${IB_CONFIG}

	echo "${IB_PLAT_CPU}" > "$_arch_marker"
}

do_build () {
	echo "Building SO3..."

	cd ${IB_SO3_PATH}/so3
	make
}

# `deploy.sh so3`: the kernel travels in the ITB, which bsp-so3 repacks and
# writes onto p1 (bsp-so3:do_deploy_boot). No dependency on do_build —
# deploy writes what the last `build.sh so3` produced, it does not compile.
do_deploy[nostamp] = "1"
do_deploy[depends] = "bsp-so3:do_deploy_boot"
python do_deploy () {
    bb.plain("SO3 kernel deployed (ITB on p1)")
}
addtask do_deploy

do_clean[nostamp] = "1"
do_clean () {
	rm -f ${TMPDIR}/stamps/so3*
}
addtask do_clean
