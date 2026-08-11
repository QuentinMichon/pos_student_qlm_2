SUMMARY = "Sense HAT emulator (host) for the SO3 sense-hat bridge"
DESCRIPTION = "Prepares a self-contained Python virtual environment under \
build/tmp that hosts the (in-tree, NumPy-2 patched) python-sense-emu package. \
This is the host-side counterpart of the SO3 guest sense-hat device: \
sense-hat/sense-hat-server.py runs sense_emu_gui and bridges the QEMU guest \
(TCP 4442) to the emulated 8x8 LED matrix. Nothing is installed into the \
target rootfs — this recipe only provisions the developer host."

# Upstream python-sense-emu is GPL-2.0-or-later; this recipe merely provisions
# a host venv (nothing shipped to target), so the license file check is skipped.
LICENSE = "CLOSED"

PR = "r0"
PV = "1.2.1"

# In-tree source, vendored under sense-hat/python-sense-emu (same "build from
# the working tree" policy as so3/usr): no remote source to fetch. The tree
# already carries the NumPy 2 fix (gui.py: ndarray.tostring() -> tobytes()).
IB_SENSE_HAT_SRC = "${IB_DIR}/sense-hat/python-sense-emu"

# Self-contained venv under the bitbake-managed build/tmp area.
IB_SENSE_HAT_DIR ?= "${TMPDIR}/sense-hat-emu"
IB_SENSE_HAT_VENV = "${IB_SENSE_HAT_DIR}/venv"

# Host-side tool, built from the in-tree source: no fetch/unpack/patch, no
# infrabase source-attach (which mkdir's an empty IB_TARGET), no install phase.
do_fetch[noexec] = "1"
do_unpack[noexec] = "1"
do_patch[noexec] = "1"
do_attach_infrabase[noexec] = "1"
do_install[noexec] = "1"

# Verify the host (apt) packages that pip cannot provide. The venv is created
# with --system-site-packages so the GUI imports the distro PyGObject/Gtk3, and
# python3-venv is needed to build the venv itself.
python do_check_sysdeps() {
    import subprocess

    def _ok(args):
        return subprocess.call(
            args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0

    missing = []
    if not _ok(['python3', '-c', 'import venv, ensurepip']):
        missing.append('python3-venv')
    # PyGObject + GTK3 typelib, required by sense_emu_gui.
    gi_check = ('import gi; gi.require_version("Gtk", "3.0"); '
                'from gi.repository import Gtk')
    if not _ok(['python3', '-c', gi_check]):
        missing.append('python3-gi')
        missing.append('gir1.2-gtk-3.0')

    if missing:
        bb.fatal(
            "Missing host packages for the Sense HAT emulator GUI:\n"
            "    sudo apt-get install %s\n"
            "(PyGObject/Gtk3 and python3-venv come from the distro, not pip.)"
            % ' '.join(missing))
}
addtask check_sysdeps before do_configure after do_patch

# Create the venv (with access to the system GObject/Gtk bindings) and make
# sure pip/wheel are current. Idempotent: reuses an existing venv.
do_configure() {
    if [ ! -x "${IB_SENSE_HAT_VENV}/bin/python3" ]; then
        echo "Creating sense-emu venv at ${IB_SENSE_HAT_VENV}"
        python3 -m venv --system-site-packages "${IB_SENSE_HAT_VENV}"
        "${IB_SENSE_HAT_VENV}/bin/python3" -m pip install --upgrade pip wheel
    else
        echo "sense-emu venv already present at ${IB_SENSE_HAT_VENV}"
    fi
}

# Install the in-tree python-sense-emu (pulls numpy/Pillow per setup.cfg, both
# already satisfied by the system via --system-site-packages). Guarded so a
# plain rebuild is instant; `bitbake sense-emu -c clean` forces a reinstall.
do_build() {
    if [ -x "${IB_SENSE_HAT_VENV}/bin/sense_emu_gui" ]; then
        echo "sense-emu already installed in the venv — skipping."
    else
        echo "Installing python-sense-emu from ${IB_SENSE_HAT_SRC}"
        "${IB_SENSE_HAT_VENV}/bin/python3" -m pip install "${IB_SENSE_HAT_SRC}"
    fi
    echo ""
    echo "Sense HAT host environment ready."
    echo "  GUI     : ${IB_SENSE_HAT_VENV}/bin/sense_emu_gui"
    echo "  Bridge  : ${IB_SENSE_HAT_VENV}/bin/python3 ${IB_DIR}/sense-hat/sense-hat-server.py"
}

# base.bbclass does not provide do_clean, so define it here (like the qemu
# recipe and usr.bbclass). Implemented in Python on purpose: a shell task needs
# ${WORKDIR}/temp for its fifo, which is often absent when cleaning a fresh or
# already-clean tree.

do_clean[nostamp] = "1"
addtask do_clean

python do_clean() {
    import glob
    import os
    import shutil

    # Wipe the prepared venv so the next build reinstalls from scratch.

    shutil.rmtree(d.getVar('IB_SENSE_HAT_DIR'), ignore_errors=True)

    # Drop this recipe's stamps so a subsequent build re-runs every task.
    # Stamps are flat under build/tmp/stamps, named "<PN>-<PV>-<PR>.do_*".

    stamps = os.path.join(d.getVar('TMPDIR'), 'stamps', d.getVar('PN') + '-*')

    for stamp in glob.glob(stamps):
        try:
            os.remove(stamp)
        except OSError:
            pass
}
