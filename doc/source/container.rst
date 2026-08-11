.. _container:

===================
The build container
===================

Building this tree needs four cross toolchains and some sixty host packages, in
versions that match. The build container provides exactly that, so nothing has
to be installed on your machine and everyone builds in the same environment —
including the teaching assistants when they reproduce your problem.

The container carries **only the environment**. Your repository stays on your
machine and is bind-mounted into it, at the **same absolute path**, so:

* everything the build writes — source trees, ``build/tmp``, the images — stays
  on your disk and belongs to **you**, not to root;
* you can alternate freely between building inside the container and (if you
  ever set one up) building natively: bitbake stamps, the buildroot host tree
  and the CMake caches all record absolute paths, and an identical path is what
  keeps them valid.

Usage
=====

.. code-block:: console

   $ dbuild.sh --build                    # build (or rebuild) the image — once
   $ dbuild.sh                            # interactive shell in the container
   $ dbuild.sh build.sh bsp-linux         # run one command, then exit
   $ dbuild.sh deploy.sh bsp-linux
   $ dbuild.sh st.sh -d
   $ dbuild.sh -h                         # help

``dbuild.sh`` lives in ``scripts/``, so after ``. ./env.sh`` it is a plain
command, usable from anywhere in the tree. Your current directory is preserved
inside the container, and with no argument you get an interactive shell with
``env.sh`` already sourced:

.. code-block:: console

   $ cd linux/usr
   $ dbuild.sh
   [pos-build] ~/pos/pos_sol/linux/usr $ makeusr.sh

Two environment variables adjust it without editing anything:

.. code-block:: console

   $ IB_DOCKER_IMAGE=pos-build:test dbuild.sh --build
   $ IB_DOCKER_OPTS="-v /media/sdcard:/media/sdcard" dbuild.sh

What is in the image
====================

Everything is under ``docker/build-env/``:

.. list-table::
   :header-rows: 1
   :widths: 24 76

   * - File
     - Role
   * - ``Dockerfile``
     - Two stages: fetch the Arm 64-bit toolchains, then install the
       environment. Its build context is that directory only — never the
       project root, which holds tens of GB of output.
   * - ``packages.txt``
     - The host packages, one per line, with a comment explaining each group.
       **This is the single source of truth**: adding a dependency there is all
       it takes.
   * - ``entrypoint.sh``
     - Creates an account matching your UID/GID (passed at run time, so one
       image serves everybody) and drops to it. Nothing runs as root.
   * - ``bashrc``
     - The rc file for the interactive shell; it is what sources ``env.sh``.

The four cross toolchains, and why they are what they are:

.. list-table::
   :header-rows: 1
   :widths: 30 44 26

   * - Prefix
     - Used for
     - Source
   * - ``arm-linux-gnueabihf-``
     - 32-bit Linux kernel + U-Boot (``virt32``, ``rpi4``)
     - apt
   * - ``arm-none-eabi-``
     - SO3 kernel, 32-bit
     - apt
   * - ``aarch64-none-linux-gnu-``
     - 64-bit Linux kernel + U-Boot (``virt64``, ``rpi4_64``)
     - Arm GNU Toolchain 12.3
   * - ``aarch64-none-elf-``
     - SO3 kernel, 64-bit
     - Arm GNU Toolchain 12.3

The 64-bit pair has to be downloaded because Ubuntu's package installs the prefix
``aarch64-linux-gnu-``, while the recipes pin ``aarch64-none-linux-gnu-``. The
*user-space* toolchains are deliberately absent from the image: ``usr-linux``
uses the one buildroot builds in ``linux/rootfs/host``, and ``usr-so3`` the MUSL
one built by the ``musl-toolchain`` recipe. Both land in your tree, so they are
built once and reused by every later container.

Graphical programs
==================

``st.sh -d`` (the QEMU window) and ``st.sh -g`` (the Sense HAT emulator) open
real windows from inside the container: ``dbuild.sh`` forwards your ``DISPLAY``,
the X socket and the X cookie. It works out of the box on a normal Linux
session, X11 or Wayland. If a window refuses to open, see
:ref:`troubleshooting`.

Hardware
========

The container runs ``--privileged`` with ``/dev`` bind-mounted, because the
storage steps need loop devices, ``mount`` and ``mkfs``. One consequence to keep
in mind: with ``IB_STORAGE_MODE = "hard"``, ``IB_STORAGE_DEVICE`` names **your
machine's** device. The container is not a sandbox — check that device before
deploying.

.. _container-platforms:

Linux, WSL2, macOS
==================

Everything here is developed and tested on **Linux**. The image itself builds
anywhere, but several of the mechanisms above rely on the container sharing the
host's kernel — and on macOS and Windows, Docker Desktop runs containers inside
a Linux virtual machine, so "the host" they see is that VM, not your machine:

.. list-table::
   :header-rows: 1
   :widths: 30 14 28 28

   * -
     - Linux
     - Windows + WSL2
     - macOS
   * - Build
     - yes
     - yes, with the tree **inside** the WSL2 filesystem (``/home/…``); on
       ``/mnt/c/…`` it is very slow
     - works, but slow, and needs a **case-sensitive** volume
   * - QEMU + graphics
     - yes
     - yes, through WSLg (Windows 11)
     - needs XQuartz and a TCP ``DISPLAY``; the socket forwarding used here does
       not apply
   * - Guest ports (ssh 2222, gdb 1234)
     - yes
     - yes
     - no — they are published inside the VM
   * - Writing a real SD card
     - yes
     - no
     - no — no USB pass-through

.. warning::

   On macOS, a case-insensitive filesystem is a hard blocker for the Linux
   source tree: it contains filenames that differ only in case (for example
   ``netfilter/xt_CONNMARK.h`` and ``xt_connmark.h``). Put the tree on a
   case-sensitive volume.

Recommended: **Windows → WSL2**, with the tree in the WSL2 filesystem.
**macOS → a Linux virtual machine**, which is less friction than Docker Desktop
for the graphical labs. Outside Linux, build a ``soft`` image and write
``filesystem/sdcard.img.<platform>`` to the card with a native tool (Raspberry Pi
Imager, ``dd``).

Adding a dependency
===================

If something is missing from the image, add it to ``docker/build-env/packages.txt``
(in the right group, with a short comment saying why) and rebuild:

.. code-block:: console

   $ dbuild.sh --build

Please do not install packages by hand inside a running container: the container
is thrown away on exit, and the next person hits your problem again.
