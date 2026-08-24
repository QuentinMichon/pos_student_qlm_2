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
	tlist="${QEMU_TARGET}"
	for t in arm-softmmu aarch64-softmmu; do
		if [ "$t" != "${QEMU_TARGET}" ] && ls build/$t/qemu-system-* >/dev/null 2>&1; then
			tlist="$tlist,$t"
		fi
	done

	echo "Configuring QEMU (target-list=$tlist)..."
	./configure --target-list=$tlist ${QEMU_OPTS}

}

do_build[nostamp] = "1"
do_build () {
	if [ "${IB_QEMU_METHOD}" = "prebuilt" ]; then
		echo "IB_QEMU_METHOD=prebuilt: copying prebuilt ${QEMU_TARGET} binary instead of compiling"
		mkdir -p ${IB_DIR}/qemu/build
		cp ${IB_QEMU_PREBUILT_DIR}/${QEMU_TARGET}/qemu-system-* ${IB_DIR}/qemu/build/
		return
	fi

	echo "Building QEMU with ${CORES} cores..."
	cd ${IB_DIR}/qemu
	make -j${CORES}
}

EXPORT_FUNCTIONS do_configure
