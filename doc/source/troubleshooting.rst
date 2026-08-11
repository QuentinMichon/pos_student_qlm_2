.. _troubleshooting:

===============
Troubleshooting
===============

The errors you are most likely to hit, what they actually mean, and what to do.
When you ask for help, say which of these you already checked — it saves everyone
time.

Read the banner first
=====================

Every front-end script prints, on startup, the tree and platform it is about to
act on:

.. code-block:: text

   [infrabase] bsp-linux  root=/home/you/pos/pos_sol  platform=virt32

A surprising number of "it doesn't work" reports are a command run against the
wrong tree or the wrong platform. Read that line before anything else.

Environment
===========

**``build.sh: command not found``**
    ``env.sh`` was not sourced in this terminal. Source it **from the root of the
    tree** — it takes the tree's location from your current directory:

    .. code-block:: console

       $ cd ~/pos/pos_sol && . ./env.sh

    Sourcing it from a subdirectory appears to work but sets the wrong root, and
    nothing on ``PATH`` will resolve. Once sourced correctly, you may ``cd``
    anywhere.

**A prompt asks "Switch env to <other tree>? [y/N]"**
    You changed directory into a *different* Infrabase tree. Answer ``y`` to
    switch, ``n`` to stay. ``ib_autoswitch_off`` silences it for the session.

Container
=========

**``image 'pos-build:1.0' not found``**
    Build it: ``dbuild.sh --build``.

**``permission denied`` on ``/var/run/docker.sock``**
    Your user is not in the ``docker`` group:

    .. code-block:: console

       $ sudo usermod -aG docker $USER      # then log out and back in

**``current directory is outside <tree>``**
    Only the tree is bind-mounted, and your current directory is reused verbatim
    inside the container. ``cd`` into the tree first.

**A window (QEMU, Sense HAT) does not open**
    The X server is refusing the container. ``xhost +local:`` on your machine is
    usually enough. Check ``echo $DISPLAY`` is not empty; under Wayland, XWayland
    must be running. On macOS, see :ref:`container-platforms`.

Build
=====

**``sudo: a password is required`` in the middle of a build or deploy**
    Only on a **native** host, and only once: the storage steps escalate
    individual commands with ``sudo -n``, which needs a credential that survives
    into bitbake's subprocesses. Run:

    .. code-block:: console

       $ scripts/common/setup_sudo.sh

    Inside the container this never happens — it is already arranged.

**A task fails with ``No such file or directory: …/temp/fifo.NNNN``**
    Leftover from a build interrupted with ``Ctrl-C``. ``build.sh`` repairs these
    stale work directories on its next run, so simply run your build again.

**The build succeeds but the change has no effect**
    Almost always a question of scope: you rebuilt a component but did not
    redeploy, or you rebuilt the wrong one. The mapping is in
    :ref:`build_system` ("Fast edit/build loops"). When in doubt, the sledgehammer
    is:

    .. code-block:: console

       $ build.sh -c bsp-linux && deploy.sh bsp-linux

**``No ITS selected for platform 'X': set IB_TARGET_ITS:<os>:X …``**
    The boot image is chosen by an ``IB_TARGET_ITS`` line in
    ``build/conf/local.conf``, and every candidate for that platform is
    commented out. The message names the exact variable and lists the values it
    accepts; uncomment one. The neighbouring message, *ITS '…' has no template*,
    means the variable is set to a name no ``.its`` file matches — a typo, or an
    ITS that belongs to another platform.

**``Refusing to re-attach so3 (would overwrite the files above)``**
    ``so3/``, like ``u-boot/`` and ``qemu/``, is **generated**: it is fetched and
    then patched from the recipe's patch set. Editing it directly has no safety
    net, so the build refuses to overwrite your edits rather than destroying
    them. Fold them into the patch set with ``bitbake so3 -c updiff``, or, if
    you truly want them gone, ``IB_FORCE_ATTACH=1`` re-attaches and keeps the
    previous tree in ``so3.back``.

**``buildroot: inputs unchanged … skipping``**
    Not an error: nothing buildroot consumes has changed, so the root filesystem
    is not regenerated. ``build.sh -c buildroot`` rebuilds it anyway.

**Anything looks stale after switching platform**
    The kernel and buildroot keep a ``.config`` that does not know the platform
    changed under it. Clean the recipe: ``build.sh -c linux``, ``build.sh -c
    buildroot``. As a last resort, ``rm -rf build/tmp`` starts from scratch —
    correct, but it costs you a full rebuild. Never delete ``build/`` itself: it
    holds the layers and is tracked in git.

Deploy
======

**``sdcard.img.<platform> does not exist``**
    In ``soft`` mode ``deploy.sh`` creates it for you; if it complains, run
    ``init_storage.sh`` explicitly. In ``hard`` mode it is deliberate: prepare the
    card first (see :ref:`running-hardware`).

**A redeploy seems to change nothing**
    The storage image is still mounted from a previous run, so the deploy reuses
    that mount. Unmount and redeploy:

    .. code-block:: console

       $ umount.sh
       $ deploy.sh bsp-linux

Running
=======

**U-Boot starts, then nothing**
    The FIT image is missing or was not deployed. Check ``filesystem/`` holds
    ``<platform>.itb`` and ``sdcard.img.<platform>``, and redeploy.

**``st.sh`` exits immediately, or does nothing at all**
    Check the platform: on ``rpi4`` / ``rpi4_64`` there is nothing to emulate,
    ``st.sh`` only knows the ``virt`` machines. Select ``virt32`` or ``virt64`` in
    ``local.conf`` to run under QEMU.

**The Sense HAT window opens but the LED matrix stays blank**
    Check the guest console for ``connected to Sense-HAT server!``. If the guest
    never connected, you started QEMU without ``-g``. If it did connect and the
    matrix is still blank, the emulator was started in an environment missing its
    graphics bindings — inside the container everything needed is installed, so
    prefer ``dbuild.sh st.sh -g`` over a hand-rolled setup.

**The emulator refuses to start after QEMU was killed**
    Its shared-memory files survived. Remove them:

    .. code-block:: console

       $ rm -f /dev/shm/rpi-sense-emu-*

**I cannot leave QEMU**
    ``Ctrl-A x``. ``Ctrl-C`` goes to the guest, not to QEMU.

Still stuck?
============

Collect, in this order: the banner line, the exact command, and the **last 30
lines** of output (``-v`` on ``build.sh`` / ``deploy.sh`` gives the full bitbake
log). A build failure without those is not something anyone can help with.
