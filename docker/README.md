**This directory contains the Docker environments of the POS tree.**

- [POS build & run environment](#pos-build--run-environment) — the one to use
  for the labs: `scripts/dbuild.sh` builds, deploys and runs the tree without
  installing a single toolchain on your machine.
- [SO3 images](#so3-images) — inherited from the upstream SO3 tree (CI build
  environment and the LVGL performance images); unrelated to the POS labs.

# POS build & run environment

The build container carries **only the environment** — the cross toolchains, the
host packages, CMake, Python — and **no project source**. The repository stays on
the host and is bind-mounted at its **own absolute path**, so the same tree can
be built from inside or outside the container interchangeably: bitbake stamps,
the buildroot host tree, the CMake caches and the `*.attach.sha256` manifests all
embed absolute paths and would otherwise be invalidated on every switch.

Same model as the `edgem1` tree — keep the two in step when either moves.

## Getting started

```bash
scripts/dbuild.sh --build            # build the image (once)
dbuild.sh build.sh bsp-linux         # build   (bsp-so3 for SO3)
dbuild.sh deploy.sh bsp-linux        # deploy  (FIT + rootfs + sdcard)
dbuild.sh st.sh -d                   # run under QEMU, with the screen
```

It lives in `scripts/`, which `env.sh` puts on `PATH`, so after `. ./env.sh`
(from the repository root) it works as a bare command from anywhere in the tree —
like `build.sh` / `deploy.sh` / `st.sh`. It also resolves the tree from its own
location, so `./scripts/dbuild.sh …` works with no `env.sh` at all.

## The entry point — `scripts/dbuild.sh`

One script for everything: `--build` builds the image, no argument opens an
**interactive shell** with `env.sh` already sourced, and anything else is run as
a command inside the container.

```bash
dbuild.sh                            # interactive shell in the container
dbuild.sh build.sh -l                # one command, then exit
dbuild.sh st.sh -g                   # QEMU + the Sense HAT emulator GUI
dbuild.sh -h                         # help
IB_DOCKER_IMAGE=pos-build:test dbuild.sh --build
IB_DOCKER_OPTS="-v /media/sdcard:/media/sdcard" dbuild.sh
```

The interactive shell is the natural place to work: the prompt is marked
`[pos-build]`, the paths are identical to the host's, and the whole host
workflow applies verbatim — `build.sh`, `deploy.sh`, `st.sh` (including `-d` and
`-g`), `makeusr.sh`, `mount.sh`, … The directory you invoked `dbuild.sh` from is
preserved inside the container.

## The image — `docker/build-env/`

| File | Role |
|---|---|
| [`Dockerfile`](./build-env/Dockerfile) | Two stages: fetch the two Arm 64-bit toolchains, then the environment proper. Build context is this directory only — never the project root, which holds tens of GB of build output. |
| [`packages.txt`](./build-env/packages.txt) | **Single source of truth** for the host packages, installed verbatim. Adding a dependency there is enough. |
| [`entrypoint.sh`](./build-env/entrypoint.sh) | Materialises an account matching `HOST_UID`/`HOST_GID` (passed at *run* time, so one image serves every user and the CI runner) and drops to it with `setpriv`. Nothing comes back root-owned. |
| [`bashrc`](./build-env/bashrc) | rc file for the interactive shell: sources `env.sh` **in that shell**, so its `cd`/`pushd`/`popd` wrappers and `ib_autoswitch_*` functions exist. |

Cross toolchains, and where each comes from:

| Prefix | Used for | Source |
|---|---|---|
| `aarch64-none-linux-gnu-` | 64-bit Linux kernel + U-Boot (virt64, rpi4_64) | Arm GNU Toolchain 12.3, downloaded |
| `aarch64-none-elf-` | SO3 kernel / AVZ, 64-bit (`CONFIG_CROSS_COMPILE`) | Arm GNU Toolchain 12.3, downloaded |
| `arm-linux-gnueabihf-` | 32-bit Linux kernel + U-Boot (virt32, rpi4) | apt |
| `arm-none-eabi-` | SO3 kernel, 32-bit (`CONFIG_CROSS_COMPILE`) | apt |

The 64-bit pair must be downloaded because Ubuntu's `gcc-aarch64-linux-gnu`
installs the prefix `aarch64-linux-gnu-`, not the `aarch64-none-linux-gnu-` that
`IB_TOOLCHAIN` and the patched kernel Makefile pin. The user-space toolchains are
deliberately absent: `usr-linux` uses the one buildroot produces in
`linux/rootfs/host`, `usr-so3` the MUSL one built by `meta-toolchain` — both land
in the mounted tree, so they are built once and reused by every later container.

## What the container gets, and why

| `docker run` flag | Why |
|---|---|
| `-v $IB_ROOT:$IB_ROOT -w $cwd` | Same absolute path as on the host (see above), and your current directory is preserved. |
| `--privileged`, `-v /dev:/dev` | `build.sh filesystem`, `bsp-*` and every `deploy.sh` need loop devices, `mount` and `mkfs`. Loop devices are a **host-kernel** resource, so concurrent builds contend for them exactly as they do outside a container. |
| `--network host` | Keeps `st.sh`'s slirp forwards (guest ssh on 2222), the GDB stub and the Sense HAT bridge (4442) reachable from the host without publishing ports, and lets the recipes fetch through the host resolver. |
| `$DISPLAY` + `/tmp/.X11-unix` + `XAUTHORITY` | `st.sh -d` (QEMU GTK window) and `st.sh -g` (Sense HAT GUI). The cookie is mounted **at its own path**: the container user has a different `HOME`, and under Wayland XWayland puts the cookie in `/run/user/<uid>/` anyway. |
| `-e HOST_UID` / `-e HOST_GID` | Consumed by the entrypoint (see above). |
| `$SSH_AUTH_SOCK` | A git fetch over SSH from inside; nothing is copied into the image. |
| `-i`, plus `-t` only on a real terminal | Without `-i`, piping into a containerised command silently delivers nothing (`printf 'cmd\n' \| dbuild.sh st.sh` would never reach the guest console); `-t` without a terminal breaks CI logs. |

Two settings inside the image are equally load-bearing:

- **`Defaults !authenticate`** in `/etc/sudoers.d/build-env`, on top of
  `NOPASSWD:ALL`. The front-end scripts open their sudo session with `sudo -v`,
  which validates the *user*, not a command: sudo then asks for a password as
  soon as any applicable rule requires one — and the build user also matches
  Ubuntu's `%sudo ALL=(ALL:ALL) ALL`. Without it, `sudo -n true` succeeds while
  `sudo -v` fails with *"a terminal is required to read the password"*, and every
  `build.sh bsp-linux*` / `deploy.sh` dies in `sudo_session_start`.
- **`python3-gi-cairo`**, whose absence is silent: without the pycairo
  foreign-struct converter every Gtk `draw` callback raises `TypeError:
  Couldn't find foreign struct converter for 'cairo.Context'`, so the Sense HAT
  emulator opens with working sliders and a **blank 8×8 LED matrix** while the
  data path is perfectly fine. `sense-hat-server.py` starts the GUI with
  `stderr=devnull`, so the exception reaches no log.

## Configuration

**The scripts never touch `build/conf/local.conf`** — the platform
(`IB_PLATFORM`), the defconfigs, the ITS selection and the storage mode all come
from it, exactly as on the host. Edit it, then rebuild.

- `virt32` / `virt64` — QEMU targets: `st.sh` boots them.
- `rpi4` / `rpi4_64` — physical targets: the deploy writes the SD card. `/dev` is
  shared with the host, so `IB_STORAGE_DEVICE` names the **host's** device and
  `--privileged` means nothing stops the write — the container is not a sandbox
  for `IB_STORAGE_MODE = "hard"`. There is nothing to emulate on those, and
  `st.sh` simply does nothing (it only knows the `virt*` machines).

## Host platforms (Linux / WSL2 / macOS)

Developed and tested on **Linux**. The image itself is plain Ubuntu and builds
anywhere, but several of the flags above rely on the container sharing the host's
kernel — on macOS and Windows, Docker Desktop runs containers inside a **Linux
VM**, so "the host" they see is that VM, not your machine:

| | Linux | Windows + WSL2 | macOS |
|---|---|---|---|
| Build (`dbuild.sh`) | ✅ | ✅ repo **inside** the WSL2 fs (`/home/…`); on `/mnt/c/…` it is very slow | ⚠️ works, but slow (VirtioFS) and needs a **case-sensitive** volume |
| QEMU + GUI (`st.sh -d/-g`) | ✅ | ✅ via WSLg (Win 11) | ⚠️ needs XQuartz + a TCP `DISPLAY`; the `/tmp/.X11-unix` plumbing does not apply |
| Guest ports (ssh 2222, GDB 1234) | ✅ `--network host` | ✅ | ❌ `--network host` binds in the VM — needs explicit `-p` publishing |
| SD-card write (`IB_STORAGE_MODE = "hard"`) | ✅ | ❌ | ❌ no USB passthrough: `/dev` is the VM's |

- **macOS case-insensitivity is a hard blocker for the kernel tree**, not a
  detail: `linux/` contains filenames differing only by case (e.g.
  `netfilter/xt_CONNMARK.h` vs `xt_connmark.h`). Use a case-sensitive APFS
  volume for the tree.
- **Apple Silicon** should be fine natively: the Dockerfile picks the Arm
  toolchains with `$(uname -m)` and Arm publishes aarch64-hosted builds. Don't
  force `--platform linux/amd64` — emulating x86 for a full BSP build is
  unusably slow.
- Elsewhere than Linux, build with a `soft` image and flash
  `filesystem/sdcard.img.<plat>` with a native tool (Raspberry Pi Imager, `dd`).
- Recommended: **Windows → WSL2** (repo in the WSL2 filesystem; Docker Engine
  installed inside WSL2 avoids Docker Desktop's path translation).
  **macOS → a Linux VM** is less friction than Docker Desktop for the graphical
  labs.

> [!NOTE]
> The non-Linux columns are reasoned from Docker Desktop's architecture, not
> measured — no macOS/Windows host was available. Making the wrappers portable
> (Darwin → XQuartz TCP display, `-p` publishing instead of `--network host`, no
> `/dev` mount) is a contained change if the labs ever need it.

## Troubleshooting

- **`image 'pos-build:1.0' not found`** — run `dbuild.sh --build`.
- **`current directory is outside <tree>`** — only the tree is mounted, and the
  cwd is reused verbatim inside the container; `cd` into the tree first.
- **A GUI stays black or GTK fails to connect** — the X server is refusing the
  container: `xhost +local:` on the host is usually enough. On Wayland make sure
  XWayland is running (`echo $DISPLAY` must be non-empty).
- **snap-packaged Docker** — the confined daemon can only bind-mount paths under
  `$HOME`; `dbuild.sh` says so once and skips the affected mount. Prefer Docker
  from the apt repository.
- **The first build is very long** — the MUSL toolchain, buildroot and QEMU are
  all built from source, into `build/tmp` in the mounted tree. Once, not once per
  container.

# SO3 images

> The images below come from the upstream SO3 tree and build **SO3 only**, with
> the repository copied into the container at `/so3` (not bind-mounted). They are
> not used by the POS labs — use the POS environment above for those.

Inside them the kernel is at `/so3/so3/so3`, the user space at `/so3/so3/usr` and
the bundled LVGL at `/so3/so3/usr/lib/lvgl`.

## Base build environment

- [`Dockerfile.toolchains`](./Dockerfile.toolchains) — Ubuntu image with the
  bitbake host dependencies, the SO3 build tools (dtc, u-boot-tools, mtools, QEMU
  build deps, …) and the **bare-metal kernel** cross toolchains
  (`aarch64-none-elf`, `arm-none-eabi`). The MUSL user-space toolchains are **not**
  built here — they are produced by the `meta-toolchain` layer during the build.
- [`Dockerfile.env`](./Dockerfile.env) — a thin layer over the toolchains image,
  used by the `Build` CI to compile SO3 with the repository mounted at `/so3`.

## LVGL performance test images

- [`Dockerfile.lvperf_32b`](./Dockerfile.lvperf_32b)
- [`Dockerfile.lvperf_64b`](./Dockerfile.lvperf_64b)

Images with SO3 pre-built using the `virtXX_lvperf_defconfig` configuration, used
to run [LVGL](https://lvgl.io/) performance tests under the patched QEMU.

### Getting Started

**Build** the images from the repository root. Use **`--network=host`**: the
image build fetches the components (QEMU tarball, U-Boot/AVZ git) via
Infrabase, and on hosts where the Docker *bridge* network can't resolve/reach
external mirrors (common with systemd-resolved or a VPN), the build's
`do_fetch` fails with a wget network error — host networking uses the host
resolver and works.
```bash
# 32-bit
docker build --network=host . -f docker/Dockerfile.lvperf_32b -t so3-lvperf32b
# 64-bit
docker build --network=host . -f docker/Dockerfile.lvperf_64b -t so3-lvperf64b
```

**Run** them. `--privileged` is **required**: the SD-card image is created with
`losetup`/`mkfs`/`mount` (this cannot be done during `docker build`, which is not
privileged — hence the build-time / run-time split below). Add `--network=host`
too (same reason as the build — the run-time `usr-so3` rebuild may fetch LVGL):
```bash
docker run -it --privileged --network=host -v /dev:/dev so3-lvperf64b   # or so3-lvperf32b
```

### Technical Details

- **At image-build time** (non-privileged), Infrabase builds the emulator and the
  full BSP. `build.sh bsp-so3` is privilege-free: it only compiles (the MUSL
  toolchain via `meta-toolchain`, the kernel, the user space, U-Boot) and creates
  an empty `rootfs.fat`. The privileged rootfs loop-mount is deferred to
  `deploy.sh`.
  ```
  build.sh -x qemu  &&  build.sh bsp-so3
  ```
- **At container-run time** (privileged), the entrypoint rebuilds the user space
  (picking up a mounted LVGL), creates+formats the SD-card image (`build.sh -x filesystem` —
  `losetup`/`fdisk`/`mkfs`, the privileged step that cannot run at build time),
  then `deploy.sh` assembles the FIT, populates the rootfs and writes the SD-card,
  and finally QEMU runs:
  ```
  build.sh -x usr-so3  &&  build.sh -x filesystem  &&  deploy.sh bsp-so3  &&  docker/scripts/run.sh
  ```

With `virtXX_lvperf_defconfig` the kernel runs the LVGL benchmark as its init
program; when it finishes the kernel performs a **semihosting exit**, so QEMU
(`-semihosting`) halts and the container exits with the perf output on stdout.

### Adding Additional Dependencies

To install extra dependencies without rebuilding the image, mount a shell script
at `/so3/install_dependencies.sh` (the entrypoint runs it first).

### Persistence

Each run repeats the run-time steps. To cache between runs, mount the bitbake work
tree and the boot media as volumes:

- `/so3/build/tmp` — the bitbake work tree (toolchain, QEMU, kernel, usr, sstate)
- `/so3/filesystem` — the generated SD-card image

```bash
docker run -it --privileged \
    -v /dev:/dev \
    -v "$(pwd)/../so3-build-tmp-64b:/so3/build/tmp" \
    -v "$(pwd)/../so3-filesystem-64b:/so3/filesystem" \
    so3-lvperf64b
```

> [!NOTE]
> Use separate cache volumes for the 32-bit and 64-bit images.

### Customization Options

#### LVGL

The LVGL source lives at `/so3/so3/usr/lib/lvgl` and its configuration at
`/so3/so3/usr/lib/lv_conf.h`. Mount your own to benchmark them — the run-time
`build.sh -x usr-so3` rebuilds the user space against them:

```bash
docker run -it --privileged \
    -v /dev:/dev \
    -v <lvgl_path>:/so3/so3/usr/lib/lvgl \
    -v <lv_conf_path>:/so3/so3/usr/lib/lv_conf.h \
    so3-lvperf64b
```

#### SO3 kernel / U-Boot

You can also override the prebuilt kernel or U-Boot binaries:

```bash
docker run -it --privileged \
    -v /dev:/dev \
    -v <patched_so3.bin>:/so3/so3/so3/so3.bin \
    -v <patched_u-boot>:/so3/u-boot/u-boot \
    so3-lvperf64b
```
