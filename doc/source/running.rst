.. _running:

=======
Running
=======

Once ``deploy.sh`` has produced a bootable image, one script starts it:
``st.sh``. It reads the platform from ``build/conf/local.conf`` and picks the
right emulator, machine and boot mode by itself — you normally pass it nothing at
all.

.. code-block:: console

   $ dbuild.sh st.sh          # or just st.sh, from a container shell

QEMU
====

.. list-table::
   :header-rows: 1
   :widths: 22 78

   * - Command
     - What you get
   * - ``st.sh``
     - Headless: the guest's serial console on your terminal. The default.
   * - ``st.sh -d``
     - Also opens the **QEMU window** showing the guest's graphical screen
       (the PL111 display controller).
   * - ``st.sh -g``
     - Also launches the **Sense HAT emulator** and its bridge, so the guest's
       LED matrix and joystick have somewhere to go.
   * - ``st.sh -d -g``
     - Both windows at once.
   * - ``st.sh -h``
     - Help.

Leave QEMU with ``Ctrl-A x``.

What the platform selects:

* ``virt32`` → ``qemu-system-arm``, machine ``virt``, CPU Cortex-A15;
* ``virt64`` → ``qemu-system-aarch64``, machine ``virt``, CPU Cortex-A72.

In both cases QEMU is the **patched** emulator built by the ``qemu`` recipe (it
carries the teaching devices, ``vext`` among them), it boots ``u-boot/u-boot``,
and it presents ``filesystem/sdcard.img.<platform>`` to the guest as a virtio
block device — the same image you would write to an SD card.

Networking is QEMU's user-mode (slirp) stack: the guest gets an address
immediately, with no privileges needed on your side. Guest port 22 is forwarded,
so from your machine:

.. code-block:: console

   $ ssh -p 2222 root@localhost

The Sense HAT emulator
======================

The Sense HAT (8×8 LED matrix, joystick, sensors) is emulated on your machine and
connected to the guest through the ``vext`` device in QEMU. Prepare it once:

.. code-block:: console

   $ dbuild.sh build.sh sense-hat

then start the system with ``-g``:

.. code-block:: console

   $ dbuild.sh st.sh -g

A *Sense HAT Emulator* window opens; the guest connects to it over a local TCP
bridge (port 4442). You should see, on the guest's console:

.. code-block:: text

   vext_try_connect: connected to Sense-HAT server!

From there, anything the guest writes to the LED devices lights up in the window,
and the window's joystick buttons are delivered to the guest as input events.

Debugging
=========

``st.sh`` always exposes a GDB stub. It prints the port on startup:

.. code-block:: text

   GDB port:  1234

(the port is 1234 plus the number of emulators already running, so parallel
sessions do not collide). Freeze the machine at reset so you can set breakpoints
before anything executes, by passing QEMU's ``-S``:

.. code-block:: console

   $ dbuild.sh st.sh -S

Then, in another terminal, point a cross GDB at the port and load the symbols
from the ELF file of whatever you are debugging (``linux/linux/vmlinux``,
``so3/so3/so3.elf``, ``u-boot/u-boot``). The tree ships a ``gdbinit`` at its root
as a starting point.

.. tip::

   For the smallest possible turnaround, remember that ``deploy.sh usr-linux``
   only refreshes the user-space part of the root filesystem — you do not have to
   redeploy the whole BSP after fixing an application.

.. _running-hardware:

Real hardware — Raspberry Pi 4
==============================

On ``rpi4`` and ``rpi4_64`` there is nothing to emulate: the image goes to an SD
card and the board boots from it. ``st.sh`` has no machine for these platforms
and will do nothing.

Setting the platform is the same as usual, in ``build/conf/local.conf``:

.. code-block:: text

   IB_PLATFORM ?= "rpi4"

Two additional settings apply to the deployment:

.. code-block:: text

   IB_STORAGE_MODE:rpi4   = "hard"        # write a real block device
   IB_STORAGE_DEVICE:rpi4 = "mmcblk0"     # ...this one

.. danger::

   ``hard`` mode writes **a real device on your machine**. There is no
   confirmation prompt, and running inside the container changes nothing —
   ``/dev`` is shared and the container is privileged. Check the device name
   every single time:

   .. code-block:: console

      $ lsblk

   Note also that the name is the one *your machine* gives the card reader, not
   the one the Pi uses. On a laptop with an internal SD reader it is typically
   ``mmcblk0``; through a USB adapter it is usually ``sdX`` — and ``sda`` is very
   often your system disk.

Prepare the card once, then deploy:

.. code-block:: console

   $ dbuild.sh init_storage.sh            # partition + format the card
   $ dbuild.sh build.sh bsp-linux
   $ dbuild.sh deploy.sh bsp-linux

Unlike ``soft`` mode, ``hard`` mode never partitions the card behind your back:
``init_storage.sh`` is a deliberate step, and later deploys only mount the
existing partitions and copy into them. You can check you are about to write the
right thing by looking at the partition labels this build system creates —
``boot`` (FAT) and ``rootfs1`` (ext4):

.. code-block:: console

   $ lsblk -o NAME,SIZE,LABEL,MOUNTPOINT

Serial console
--------------

The Pi's console is its **mini UART**, exposed as ``ttyS0`` on the guest side at
**115200 8N1**. Connect a USB-serial adapter to the board's UART pins and attach
to it from your machine, for example:

.. code-block:: console

   $ picocom -b 115200 /dev/ttyUSB0

That console is where U-Boot and the kernel talk to you, and it is your only
window when the board does not come up. ``picocom`` is in the container too, if
you prefer to keep everything in one place — ``/dev`` is shared.
