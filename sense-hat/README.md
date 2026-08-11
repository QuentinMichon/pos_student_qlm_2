# Sense HAT — host emulator environment

Host-side counterpart of the SO3 guest `sense-hat` device. `sense-hat-server.py`
runs `sense_emu_gui` (the emulated 8×8 LED matrix + sensors) and bridges the
QEMU guest — which connects on TCP port **4442** — to the emulator.

## Prepare the environment

The `meta-sense-hat` layer provisions a self-contained Python virtualenv under
`build/tmp/sense-hat-emu/venv` with the in-tree `python-sense-emu` (already
patched for NumPy ≥ 2). From the project root, with the build env sourced
(`. ./env.sh`):

```sh
./scripts/build.sh sense-hat
```

The recipe first checks the host packages pip cannot provide and, if any are
missing, prints the exact `apt-get` line — typically:

```sh
sudo apt-get install python3-venv python3-gi gir1.2-gtk-3.0
```

Re-running is instant (guarded); `./scripts/build.sh -c sense-hat` forces a
clean reinstall.

## Run

Activate the venv first — `sense-hat-server.py` spawns `sense_emu_gui` by name,
so it must be on `PATH`:

```sh
. build/tmp/sense-hat-emu/venv/bin/activate
python3 sense-hat/sense-hat-server.py
```

This opens the emulator GUI and listens on port 4442 for the QEMU guest. The
LED matrix stays dark until the guest sends `{"device":"led",...}` packets.

### Test the LED matrix without a guest

```sh
. build/tmp/sense-hat-emu/venv/bin/activate
python3 sense-hat/test_leds.py
```

Displays a colour checkerboard and stays alive (Ctrl-C to quit) so the GUI keeps
refreshing.
