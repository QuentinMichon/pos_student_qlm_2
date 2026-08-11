.. _getting_started:

===============
Getting started
===============

This page takes you from a fresh clone to a booted system. Budget an hour for
the first run: the build compiles a cross toolchain, a root filesystem and an
emulator from source. Everything after that is incremental and fast.

What you need
=============

* **Linux** (Ubuntu 24.04 is what everything is tested on). On Windows use
  **WSL2** with the tree inside the WSL2 filesystem; on macOS a Linux VM is the
  path of least resistance — see :ref:`container-platforms`.
* **Docker**, and your user in the ``docker`` group:

  .. code-block:: console

     $ sudo usermod -aG docker $USER      # then log out and back in
     $ docker run --rm hello-world        # must work without sudo

* About **30 GB** of free disk space, and a network connection for the first
  build (the recipes fetch U-Boot, QEMU, buildroot packages and the toolchain
  sources).

You do **not** need to install any cross compiler: the build container carries
all four of them.

Get the tree
============

.. code-block:: console

   $ git clone <repository-url> pos_sol
   $ cd pos_sol
   $ . ./env.sh

``env.sh`` must be sourced **from the root of the tree** — it takes the tree's
location from your current directory. It puts ``scripts/`` and ``bitbake`` on
your ``PATH``, so from then on ``build.sh``, ``deploy.sh``, ``st.sh`` and
``dbuild.sh`` work as plain commands, from anywhere inside the tree. Do it once
per terminal.

Every script prints a banner telling you which tree and platform it is about to
act on. Get in the habit of reading it:

.. code-block:: console

   [infrabase] bsp-linux  root=/home/you/pos/pos_sol  platform=virt32

Build the container
===================

.. code-block:: console

   $ dbuild.sh --build

This builds the ``pos-build:1.0`` image: the cross toolchains and every host
package the build needs. It takes a few minutes and is done **once** (repeat it
only when ``docker/build-env/`` changes). See :ref:`container` for what is
inside and why.

Choose the platform
===================

The target is selected in ``build/conf/local.conf`` by a single variable. Open
it and make sure exactly one ``IB_PLATFORM`` line is active:

.. code-block:: text

   IB_PLATFORM ?= "virt32"
   # IB_PLATFORM ?= "virt64"
   # IB_PLATFORM ?= "rpi4"
   # IB_PLATFORM ?= "rpi4_64"

Start with ``virt32``: it is emulated, so nothing can go wrong that a rebuild
does not fix, and it is the platform the first labs use.

Build, deploy, run
==================

Three steps, always in this order:

.. code-block:: console

   $ dbuild.sh build.sh bsp-linux        # compile everything
   $ dbuild.sh deploy.sh bsp-linux       # assemble the boot image + root filesystem
   $ dbuild.sh st.sh                     # boot it under QEMU

* **build** compiles the whole dependency tree: U-Boot, the kernel, the
  buildroot root filesystem, the user-space applications.
* **deploy** turns that into something bootable: it builds the FIT image
  (``filesystem/virt32.itb``), creates and partitions the SD-card image
  (``filesystem/sdcard.img.virt32``) and fills it.
* **st.sh** starts QEMU on that image. You land on a serial console; log in and
  you have a shell on your own system.

Leave QEMU with ``Ctrl-A x``.

To build SO3 instead of Linux, use the ``bsp-so3`` recipe — same three steps.

Working in the container
========================

Prefixing every command with ``dbuild.sh`` gets old. Run it with no argument
and you get an interactive shell inside the container, with ``env.sh`` already
sourced and the tree at the very same path:

.. code-block:: console

   $ dbuild.sh
   [pos-build] ~/pos/pos_sol $ build.sh bsp-linux
   [pos-build] ~/pos/pos_sol $ deploy.sh bsp-linux
   [pos-build] ~/pos/pos_sol $ st.sh -d
   [pos-build] ~/pos/pos_sol $ exit

This is how most people work: edit with your usual editor **outside** the
container, build and run **inside** it. Nothing is copied — it is the same
files, and everything the build produces stays yours.

Did it work?
============

After a successful deploy you should have:

.. code-block:: console

   $ ls filesystem/
   sdcard.img.virt32   u-boot.bin   virt32.itb   work

and ``st.sh`` should show U-Boot loading the FIT image, then the kernel booting,
then a login prompt. If any of that is missing, go to
:ref:`troubleshooting`.

Next steps
==========

* :ref:`build_system` — what those recipes actually are, and the fast loops that
  save you from rebuilding the world for a one-line change.
* :ref:`running` — the graphical mode, the Sense HAT emulator, the debugger, and
  the real Raspberry Pi 4.
