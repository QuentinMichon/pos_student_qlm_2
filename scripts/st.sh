#!/bin/bash

# Copyright (c) 2025-2026 EDGEMTech SA

# Resolve project root from this script's own location, cd there, and
# source env.sh — prompting the user first if the parent shell points
# at a different tree. Every relative path below (filesystem/...,
# build/conf/local.conf) is anchored on that root. See
# scripts/common/setup_env.sh.

. "$(cd "$(dirname "$(command -v -- "$0")")" && pwd)/common/setup_env.sh"

QEMU_AUDIO_DRV="none"
GDB_PORT_BASE=1234

# Parse our own options (currently just -g) out of the argument list before
# what's left is forwarded to QEMU as USR_OPTION. -g also brings up the Sense
# HAT emulator GUI (see launch_sense_hat_gui).
WITH_GUI=0
WITH_DISPLAY=0
POSARGS=()
for _a in "$@"; do
    case "$_a" in
        -g) WITH_GUI=1 ;;
        -d) WITH_DISPLAY=1 ;;
        -h|--help)
            echo "Usage: $(basename "$0") [-d] [-g] [qemu-option]"
            echo "  -d   graphical: open the QEMU GTK window showing the guest PL111/LVGL screen"
            echo "  -g   also launch the Sense HAT emulator GUI + bridge (host TCP 4442)"
            exit 0 ;;
        *)  POSARGS+=("$_a") ;;
    esac
done
set -- "${POSARGS[@]}"
USR_OPTION=$1
# QEMU_BIN is selected per IB_PLATFORM below (qemu-system-aarch64 for
# virt64, qemu-system-arm for virt32).

N_QEMU_INSTANCES=`ps -A | grep qemu-system | wc -l`

SENSE_HAT_PID=""

SENSE_EMU_PIDFILE="/dev/shm/rpi-sense-emu-pid"

# True when the python-sense-emu lock names a live emulator.
#
# The command line is read straight from /proc by builtins, with no child
# process. The `ps -p $pid | grep -q sense_emu` this replaces matched ITSELF:
# a fresh container hands out PIDs in the same order on every run, so the
# grep of one run can land on the PID the previous run's GUI held, and grep's
# own argv contains "sense_emu". The stale lock then passed for a live one,
# and the next GUI refused to start ("Another process is currently acting as
# the Sense HAT emulator"). A zombie is caught too: its cmdline is empty,
# while the kill(pid, 0) python-sense-emu relies on still succeeds.
sense_emu_lock_is_live() {
    local _pid _argv=()
    read -r _pid 2>/dev/null < "$SENSE_EMU_PIDFILE" || return 1
    case "$_pid" in ''|*[!0-9]*) return 1 ;; esac
    mapfile -d '' _argv 2>/dev/null < "/proc/$_pid/cmdline" || return 1
    [[ "${_argv[*]}" == *sense_emu* ]]
}

# Kill the whole Sense HAT process group (server + sense_emu_gui + its sensor
# helpers) when st.sh exits. The server is started via setsid, so its PID is
# also its process-group id.
#
# A GUI killed by a signal never releases its lock, so release it here once
# the GUI is gone, rather than leave the next run to guess whether the PID in
# it still means anything: after a containerised run it names a process of a
# namespace that no longer exists.
cleanup_sense_hat() {
    [ -n "$SENSE_HAT_PID" ] || return
    kill -TERM -"$SENSE_HAT_PID" 2>/dev/null
    for _i in 1 2 3 4 5 6 7 8 9 10; do
        sense_emu_lock_is_live || break
        sleep 0.1
    done
    kill -KILL -"$SENSE_HAT_PID" 2>/dev/null
    sense_emu_lock_is_live || rm -f /dev/shm/rpi-sense-emu-*
}

# Bring up the host-side Sense HAT emulator (sense_emu_gui + the TCP 4442
# bridge) from the venv prepared by `build.sh sense-hat`. Started before QEMU so
# it's listening by the time the guest connects; output goes to a log to keep
# the serial console clean.
launch_sense_hat_gui() {
    _venv="$IB_ROOT_DIR/build/tmp/sense-hat-emu/venv"
    _server="$IB_ROOT_DIR/sense-hat/sense-hat-server.py"
    _log="$IB_ROOT_DIR/build/tmp/sense-hat-emu/server.log"
    if [ ! -x "$_venv/bin/python3" ]; then
        echo -e "\033[01;31m[sense-hat] venv absent — run './scripts/build.sh sense-hat' first\033[0;37m" >&2
        exit 1
    fi

    # python-sense-emu refuses to start when /dev/shm/rpi-sense-emu-pid names a
    # live process ("Another process is acting as an emulator"). That check
    # misfires after a run launched inside the build container: the file then
    # holds a PID from the container's namespace, and a small number almost
    # always matches a live kernel thread on the host — pid 43 was ksoftirqd/8
    # here. /dev/shm belongs to the host, so the bogus lock outlives the
    # container and never expires on its own.
    #
    # So trust the PID only when it really is an emulator, and otherwise clear
    # the whole set: they are shared-memory artefacts, recreated at startup.
    # A real one means another `st.sh -g` is up: it also holds TCP 4442, so
    # say so here rather than let the GUI fail in a dialog box.

    if sense_emu_lock_is_live; then
        read -r _pid < "$SENSE_EMU_PIDFILE"
        echo -e "\033[01;31m[sense-hat] an emulator is already running (pid $_pid) — quit the other 'st.sh -g', or: kill $_pid\033[0;37m" >&2
        exit 1
    fi
    if [ -e "$SENSE_EMU_PIDFILE" ]; then
        read -r _pid 2>/dev/null < "$SENSE_EMU_PIDFILE"
        echo -e "\033[01;33m[sense-hat] stale emulator lock (pid ${_pid:-?} is not an emulator) — clearing\033[0;37m" >&2
        rm -f /dev/shm/rpi-sense-emu-*
    fi

    echo -e "\033[01;36m[sense-hat] launching emulator GUI + bridge (TCP 4442), log: $_log\033[0;37m"
    # setsid → own process group (clean teardown). venv bin on PATH so the
    # server's Popen(['sense_emu_gui']) resolves to the prepared GUI.
    setsid env PATH="$_venv/bin:$PATH" "$_venv/bin/python3" "$_server" > "$_log" 2>&1 &
    SENSE_HAT_PID=$!
    trap cleanup_sense_hat EXIT
    # Let the server bind 4442 + open the GUI before the guest boots.
    sleep 1
}

launch_qemu() {
    QEMU_MAC_ADDR="$(printf 'DE:AD:BE:EF:%02X:%02X\n' $((N_QEMU_INSTANCES)) $((N_QEMU_INSTANCES)))"

    GDB_PORT=$((${GDB_PORT_BASE} + ${N_QEMU_INSTANCES}))

    echo -e "\033[01;36mMAC addr: " ${QEMU_MAC_ADDR} "\033[0;37m"
    echo -e "\033[01;36mGDB port: " ${GDB_PORT} "\033[0;37m"

    while IFS= read -r line; do
      # Check if the line starts with "IB_PLATFORM"
      if [[ $line == IB_PLATFORM* ]]; then
    	  # Extract the value between the quotes
    	  value=$(echo "$line" | awk -F'"' '{print $2}')
    
    	  # Set the IB_PLATFORM variable to the extracted value
    	  IB_PLATFORM="$value"
    	  break
      fi
    done < build/conf/local.conf

    # (An AVZ boot used to be detected here by grepping this file for the
    # selected ITS, so that QEMU could be given EL2. That is now stated by
    # the build in filesystem/boot.conf — see below — which also sees the
    # ITS a layer declares, something this grep never could.)

    # One guest per storage image.
    #
    # Every instance attaches filesystem/sdcard.img.<platform> with
    # file.locking=off, so a second guest on the SAME image writes into the
    # filesystem the first one is already writing to — silently.
    #
    # Scoped to the image rather than to QEMU as a whole, on purpose: two
    # platforms use two images and may legitimately run side by side, which
    # is what the per-instance MAC / GDB port offsets above are for. Only the
    # same-image case is refused.
    #
    # The pgrep pattern deliberately requires a trailing space after the
    # binary name so it cannot match this script's own command line.
    _st_img="filesystem/sdcard.img.${IB_PLATFORM}"
    _st_busy=""
    for _p in $(pgrep -f 'qemu-system-[a-z0-9]+ ' 2>/dev/null); do
        tr '\0' ' ' < /proc/$_p/cmdline 2>/dev/null | grep -Fq -- "$_st_img" || continue
        # The same spelling in two trees is not the same file: every tree
        # names its image "filesystem/sdcard.img.<plat>" and QEMU records
        # that relative path verbatim. Resolve it through the guest's own
        # cwd before deciding, or a guest in a sibling tree would block us.
        [ "$(readlink -f /proc/$_p/cwd 2>/dev/null)/$_st_img" = "$PWD/$_st_img" ] \
            && _st_busy="${_st_busy}${_p} "
    done
    if [ -n "${_st_busy}" ]; then
        printf "Error: a QEMU guest is already using %s (pid %s).\n" \
            "$_st_img" "${_st_busy% }" >&2
        printf "       Two guests on one image corrupt it. Quit that one first:\n" >&2
        printf "       Ctrl-A x in its console, or kill %s\n" "${_st_busy% }" >&2
        exit 1
    fi

    # Display mode. Default: headless (serial console only). With -d: open the
    # QEMU GTK window that presents the guest PL111 CLCD (the LVGL screen). SO3
    # drives PL111 + PL050 (wired unconditionally into '-M virt' by the so3 QEMU
    # patch) and has no virtio-gpu, so no extra device flags are needed — just
    # switch the display backend. Use GTK, not SDL: SDL leaves the PL111 console
    # black, GTK presents it (and its View menu lists every console). On a
    # fractionally-scaled HiDPI Wayland panel, route GTK through XWayland so the
    # so3,absmouse absolute pointer maps 1:1 onto the guest surface; harmless on
    # a real X11 session.
    if [ "$WITH_DISPLAY" == "1" ]; then
        DISPLAY_OPT="-display gtk,zoom-to-fit=off"
        export GDK_BACKEND=x11
        export GDK_SCALE=1
        export GDK_DPI_SCALE=1
    else
        DISPLAY_OPT="-display none"
    fi

    # With -g, point the QEMU vext device at the sense-hat-server (TCP 4442,
    # started by launch_sense_hat_gui) so its LEDs and joystick reach the
    # emulator. Empty otherwise (the vext device then runs with no host).
    if [ "$WITH_GUI" == "1" ]; then
        SENSE_URL_OPT="-sense-url 127.0.0.1:4442"
    else
        SENSE_URL_OPT=""
    fi

    if [ "$IB_PLATFORM" == "virt64" ]; then
    QEMU_BIN="$IB_ROOT_DIR/qemu/build/qemu-system-aarch64"
    echo Starting on virt64
    # User-mode (slirp) networking: QEMU plays DHCP + DNS + NAT internally, so
    # the guest gets 10.0.2.15 immediately and NetworkManager-wait-online
    # succeeds in <1 s instead of timing out at 60 s as it did with tap+host
    # bridge that had no DHCP server. hostfwd exposes guest SSH on host
    # port 2222 for convenience. Trade-off: guest is NAT'd, no LAN visibility.
    # Bonus: no sudo needed (no tap device creation), so QEMU artefacts stay
    # owned by the regular user across runs.
    #
    # How the machine starts is not worked out here: the build knows the boot
    # chain, so the build states it, in filesystem/boot.conf written by
    # bsp.bbclass:do_deploy_boot_chain -> bsp_virt64.inc.
    #
    # It used to be guessed from which artefacts were lying in filesystem/
    # plus an IB_HYPERVISOR read out of local.conf. Both were guesses at
    # something the build already knows: the chain is normalised at parse
    # time by base.bbclass:ib_normalize_boot_axes, a layer may declare its
    # own, and the legacy "full" alias expands to a hypervisor that appears
    # in no .conf file at all. None of that is visible to a shell reading
    # local.conf.
    #
    #   "uboot", "mcuboot"   the first stage is on the card, in the raw area
    #                        ahead of p1, and the machine's boot ROM reads it
    #                        from there (bootrom-* machine properties; see
    #                        virt_bootrom_setup() in qemu/hw/arm/virt.c).
    #   the ATF chains       BL1 executes in place from address 0, so
    #                        flash0.img is pflash-mapped and EL3 is exposed.

    if [ ! -f filesystem/boot.conf ]; then
        echo "st.sh: no filesystem/boot.conf — run deploy.sh first" >&2
        return 1
    fi
    . ./filesystem/boot.conf

    echo "Boot chain: ${IB_QEMU_CHAIN}"
    MACHINE_OPT="-M ${IB_QEMU_MACHINE}"
    BOOT_OPT="${IB_QEMU_BOOT}"

    # virtio-mmio in modern (version 2) mode. QEMU defaults force-legacy=on,
    # which presents version 1, and Zephyr's virtio_mmio driver implements
    # only the modern interface — it refuses the device with "Invalid version
    # 1", so a bootloader never gets the disk its slots live on. U-Boot and
    # Linux both speak either version, so this costs the other
    # configurations nothing.
    ${QEMU_BIN} $@ ${USR_OPTION} \
		-smp 4  \
		-chardev stdio,id=char0,mux=on,signal=off \
		-mon chardev=char0 \
		-serial chardev:char0 \
		${MACHINE_OPT} -cpu cortex-a72  \
		-global virtio-mmio.force-legacy=false \
		${BOOT_OPT} \
		-device virtio-blk-device,drive=hd0 \
		-drive if=none,file=filesystem/sdcard.img.virt64,id=hd0,format=raw,file.locking=off \
		-m 1024 \
		${DISPLAY_OPT} ${SENSE_URL_OPT} \
		-netdev user,id=n1,hostfwd=tcp::2222-:22 \
		-device virtio-net-device,netdev=n1,mac=${QEMU_MAC_ADDR} \
        	-gdb tcp::${GDB_PORT}
	fi

    if [ "$IB_PLATFORM" == "virt32" ]; then
    QEMU_BIN="$IB_ROOT_DIR/qemu/build/qemu-system-arm"
    echo Starting on virt32
    # SO3 standalone on 32-bit ARM virt: U-Boot is loaded directly with
    # -kernel (no ATF / flash chain on this platform), cortex-a15 matches
    # the SO3 virt32 build. Serial console is muxed onto stdio like virt64;
    # slirp user networking keeps QEMU artefacts owned by the regular user.
    ${QEMU_BIN} $@ ${USR_OPTION} \
		-smp 4  \
		-chardev stdio,id=char0,mux=on,signal=off \
		-mon chardev=char0 \
		-serial chardev:char0 \
		-M virt -cpu cortex-a15 \
		-kernel u-boot/u-boot \
		-device virtio-blk-device,drive=hd0 \
		-drive if=none,file=filesystem/sdcard.img.virt32,id=hd0,format=raw,file.locking=off \
		-m 1024 \
		${DISPLAY_OPT} ${SENSE_URL_OPT} \
		-netdev user,id=n1,hostfwd=tcp::2222-:22 \
		-device virtio-net-device,netdev=n1,mac=${QEMU_MAC_ADDR} \
        	-gdb tcp::${GDB_PORT}
	fi


    QEMU_RESULT=$?
}

if [ "$WITH_GUI" == "1" ]; then
    launch_sense_hat_gui
fi

launch_qemu
