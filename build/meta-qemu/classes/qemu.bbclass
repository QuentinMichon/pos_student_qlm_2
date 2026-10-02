# Copyright (c) 2025-2026 EDGEMTech SA

# Class for building QEMU in infrabase

do_configure[nostamp] = "1"
qemu_do_configure () {

	if [ "${IB_QEMU_METHOD}" = "prebuilt" ]; then
		echo "IB_QEMU_METHOD=prebuilt: skipping configure"
		return
	fi

	cd ${IB_DIR}/qemu

	# Build the softmmu target of the current platform (QEMU_TARGET, selected
	# per IB_PLATFORM), but PRESERVE any other arch already built in a prior
	# run — otherwise meson would drop it. So building arm-softmmu then
	# aarch64-softmmu (or vice-versa) keeps both qemu-system-* binaries.
	# The list is always emitted in the same order, so the same set of
	# targets gives the same configure line whichever platform is current.
	tlist=""
	for t in arm-softmmu aarch64-softmmu; do
		if [ "$t" = "${QEMU_TARGET}" ] || ls build/$t/qemu-system-* >/dev/null 2>&1; then
			tlist="${tlist:+$tlist,}$t"
		fi
	done

	# QEMU's configure starts with "rm -rf build" whenever build/ was created
	# by a previous configure, so running it again throws away every object
	# and forces a full recompile. Only run it when build/ is missing or the
	# options changed; otherwise meson/ninja rebuild incrementally on their
	# own, including when a patch touches a meson.build. The stamp lives in
	# build/, so it disappears whenever configure recreates the directory.
	args="--target-list=$tlist ${QEMU_OPTS}"
	stamp=build/.ib-configure-args

	if [ -f $stamp ] && [ "$(cat $stamp)" = "$args" ]; then
		echo "QEMU already configured (target-list=$tlist), skipping configure"
		return
	fi

	echo "Configuring QEMU (target-list=$tlist)..."
	./configure $args
	echo "$args" > $stamp

}

do_build[nostamp] = "1"
do_build () {
	if [ "${IB_QEMU_METHOD}" = "prebuilt" ]; then
		echo "IB_QEMU_METHOD=prebuilt: copying the prebuilt binaries instead of compiling"
		mkdir -p ${IB_DIR}/qemu/build

		# Every prebuilt binary, whatever the platform: st.sh picks the one it
		# needs by name, and a binary filed under the wrong <target>-softmmu/
		# (qemu-system-aarch64 sat under arm-softmmu/ until 2026-09-25) is
		# still found.
		cp ${IB_QEMU_PREBUILT_DIR}/*/qemu-system-* ${IB_DIR}/qemu/build/
		return
	fi

	echo "Building QEMU with ${CORES} cores..."
	cd ${IB_DIR}/qemu
	make -j${CORES}
}

EXPORT_FUNCTIONS do_configure
