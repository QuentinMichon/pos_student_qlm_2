# Copyright (c) 2025-2026 EDGEMTech SA

SUMMARY = "AVZ Hypervisor"
DESCRIPTION = "AVZ (Agency Virtualizer) hypervisor based on polymorphic SO3 Operating System"
LICENSE = "GPLv2"

inherit avz

# Version and revision
 
PR = "r0"
PV = "6.2.3"

OVERRIDES += ":avz"

# Where the working directory will be placed in infrabase root dir
IB_TARGET = "${IB_AVZ_PATH}"

# AVZ is built from the so3 repository, fetched from upstream and PINNED —
# same source and same discipline as so3_6.2.4.bb, which is the same repo.
#
# This used to read `git:///home/rossierd/soo/so3;protocol=file` with SRCREV
# resolved by running `git -C ... rev-parse main` at parse time. That tied the
# tree to one developer's machine layout: anyone else — a student cloning this
# repository, or the very same developer inside the build container, where only
# the tree is bind-mounted — could not even PARSE the recipe:
#
#   ERROR: Failure expanding variable SRCREV ... cannot change to
#   '/home/rossierd/soo/so3': No such file or directory
#
# It also made the build irreproducible by construction: "the tip of main"
# resolves to whatever that clone happened to be at.
#
# Bumping AVZ is now the same gesture as bumping so3: move SRCREV, deliberately.
SRC_URI = "git://github.com/smartobjectoriented/so3.git;protocol=https;nobranch=1"
SRCREV = "94999d9814637dcd8870926a77599e2d545c701a"

# The stamps of this build system carry no signature hash, so a SRCREV
# change alone does not re-trigger the chain. Run do_fetch on every build
# (cheap: local git) and, ONLY when the resolved revision differs from the
# one recorded at the previous fetch, drop the downstream stamps so that
# unpack/patch/attach re-run and the avz/ tree is refreshed from the new
# main HEAD. When main has not moved, everything stays incremental.
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
            bb.plain("avz: main moved (%s -> %s), refreshing the source tree" % (last[:9], rev[:9]))
        for st in glob.glob(os.path.join(d.getVar('TMPDIR'), 'stamps', 'avz-*.do_*')):
            if not st.endswith('.do_fetch'):
                os.remove(st)
        with open(marker, 'w') as f:
            f.write(rev)
}

python do_handle_fetch_git() {

    import os
    import subprocess

    # Copy only the SO3 kernel. The repo nests the kernel under
    # <root>/so3/so3, so copy from gitdir/so3/so3 (the kernel root).

    gitdir = os.path.join(d.getVar('WORKDIR'), 'git')
    dst_dir = d.getVar('S')

    cmd = f"find . -not -path '*/.git/*' -and \( -type f -or -type d -empty \) -exec cp -r --parents -t {dst_dir} {{}} +"
    result = subprocess.run(cmd, shell=True, check=True, cwd=os.path.join(gitdir, "so3", "so3"))
}

# Apply the EDGE-M1 platform + GICv3 vGIC patch to S so that
# do_attach_infrabase faithfully reproduces the local working tree.
# Idempotent: re-applying is detected by the standard quilt machinery.

do_configure[nostamp] = "1"
do_configure () {
	cd ${IB_TARGET}
	make ${IB_CONFIG}
}

do_build[nostamp] = "1"
do_build () {
	echo "Building AVZ..."

	cd ${IB_TARGET}
	make
}

do_clean[nostamp] = "1"
do_clean () {
	rm -f ${TMPDIR}/stamps/avz*
}
addtask do_clean
