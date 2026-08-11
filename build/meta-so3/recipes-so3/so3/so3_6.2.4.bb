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
# above would NOT re-trigger the chain on its own: unpack/patch/attach would be
# skipped and the tree would silently stay at the old revision. Run do_fetch on
# every build (cheap once cloned) and, only when the resolved revision differs
# from the one recorded at the previous fetch, drop the downstream stamps so the
# tree is rebuilt from the new one. Same mechanism as the avz recipe.
do_fetch[nostamp] = "1"

python do_fetch:append() {
    import glob

    rev = d.getVar('SRCREV')
    marker = os.path.join(d.getVar('WORKDIR'), '.last_srcrev')

    last = ''
    if os.path.exists(marker):
        with open(marker) as f:
            last = f.read().strip()

    if last != rev:
        if last:
            bb.plain("so3: revision bumped (%s -> %s), refreshing the source tree" % (last[:9], rev[:9]))
        for st in glob.glob(os.path.join(d.getVar('TMPDIR'), 'stamps', 'so3-*.do_*')):
            if not st.endswith('.do_fetch'):
                os.remove(st)
        with open(marker, 'w') as f:
            f.write(rev)
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

do_clean[nostamp] = "1"
do_clean () {
	rm -f ${TMPDIR}/stamps/so3*
}
addtask do_clean
