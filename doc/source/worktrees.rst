.. _worktrees:

=========================================
One worktree per platform — ``wt.sh``
=========================================

The build keeps **all** its generated state inside the tree: the patched
``linux/`` and ``u-boot/`` sources, ``build/tmp`` (work directories, stamps,
downloads), the images. None of it is namespaced by platform. Changing
``IB_PLATFORM`` in ``build/conf/local.conf`` in place therefore leaves stale
``.config`` files and sources patched for the previous platform behind, unless
you run a full clean first.

``scripts/wt.sh`` avoids this by giving each platform its **own git worktree**.
A worktree is a second checkout of the same repository in a sibling directory,
on its own branch. Each worktree has its own copy of every generated
directory, so two platforms never share build state. You can keep ``virt32``
and ``rpi4`` built side by side and switch between them with ``cd``.

Usage
=====

.. code-block:: console

   $ wt.sh add <platform> [path]   # create a worktree for <platform>
   $ wt.sh list                    # list worktrees and their active platform
   $ wt.sh rm <platform|path>      # remove a worktree
   $ wt.sh -h                      # help

``<platform>`` is one of the ``IB_PLATFORM`` values listed in
``build/conf/local.conf`` (``virt32``, ``virt64``, ``rpi4``, ``rpi4_64``, …).
``wt.sh`` reads that list from the file itself, so it stays correct when the
list changes.

.. important::

   Run ``wt.sh`` from your **host shell**, not from inside the build
   container. ``dbuild.sh`` bind-mounts only the project root, so the sibling
   directory where the worktree goes cannot be reached from the container.
   ``wt.sh add`` detects this and stops before it changes anything in git.

Creating a worktree
===================

.. code-block:: console

   $ wt.sh add rpi4
   [wt] creating worktree for rpi4 at /home/me/pos/pos_sol-rpi4 (branch wt/rpi4 from main)
   ...
   [wt] worktree ready. Next steps:
       cd /home/me/pos/pos_sol-rpi4 && . ./env.sh
       dbuild.sh --build        # first use only
       dbuild.sh build.sh bsp-linux

``wt.sh add``:

#. creates a new branch ``wt/<platform>`` from the branch you are currently
   on;
#. checks it out in ``../<reponame>-<platform>``, or in ``[path]`` if you give
   one;
#. selects ``<platform>`` in the **new worktree's** ``build/conf/local.conf``.
   It comments out the active ``IB_PLATFORM ?= "..."`` line and uncomments the
   one for the target platform, which is the same edit you would make by hand.

The ``local.conf`` change is left **uncommitted** in that worktree on purpose.
Do not commit it: it would change the platform for everyone who merges that
branch.

.. note::

   A new worktree starts with an empty ``build/tmp``, including the download
   directory. Its first build fetches and builds everything from scratch, and
   takes the same time and disk space as a fresh clone.

Working in a worktree
=====================

Go to the worktree and load its environment, as for any tree:

.. code-block:: console

   $ cd ../pos_sol-rpi4
   $ . ./env.sh
   $ dbuild.sh build.sh bsp-linux

Once ``env.sh`` has been sourced in a shell, ``cd`` detects when you move
into a **different** tree and offers to switch the environment to it:

.. code-block:: console

   $ cd ../pos_sol

   [infrabase] env switch requested:
       current : /home/me/pos/pos_sol-rpi4
       target  : /home/me/pos/pos_sol

   Switch env to /home/me/pos/pos_sol? [y/N]

Answer ``y`` so that ``build.sh``, ``deploy.sh`` and ``st.sh`` run from the
tree you are in. If you answer ``N``, you are not asked again for that tree
until you ``cd`` into another one. To turn the prompt off for the current
shell, run ``ib_autoswitch_off``; ``ib_autoswitch_on`` turns it back on and
``ib_autoswitch_status`` shows its state.

Commits made in a worktree go to its ``wt/<platform>`` branch. To carry a fix
over to another platform, merge or cherry-pick it as usual. All worktrees
share the same repository, so branches and commits are visible from all of
them immediately.

Listing worktrees
=================

.. code-block:: console

   $ wt.sh list
   /home/me/pos/pos_sol       35eead602 [main]  [virt32]
   /home/me/pos/pos_sol-rpi4  35eead602 [wt/rpi4]  [rpi4]

The last column is the platform that is active in each worktree's
``local.conf``, as ``st.sh`` will see it. ``[?]`` means that no
``local.conf`` could be read, for example because the directory no longer
exists.

Removing a worktree
===================

.. code-block:: console

   $ wt.sh rm rpi4
   Delete now-unused branch 'wt/rpi4'? [y/N]

The argument is either a platform, which selects the worktree on branch
``wt/<platform>``, or a path. ``wt.sh rm``:

* **refuses** to remove a worktree with uncommitted changes other than the
  expected ``local.conf`` edit. Commit or discard them first, or force the
  removal with the ``git worktree remove --force`` command it prints;
* deletes the whole directory, **including its** ``build/tmp`` **and its
  images**;
* then offers to delete the ``wt/<platform>`` branch. ``git branch -d`` only
  deletes it if it has been merged, so unmerged commits are not lost.

If a worktree directory has been deleted by hand, or ``wt.sh add`` failed
halfway, git still keeps a record of it. ``wt.sh rm <platform>`` also cleans
up those records.

Common errors
=============

``unknown platform 'xyz'``
    The name does not match any ``IB_PLATFORM ?= "..."`` line in
    ``local.conf``. The error lists the known platforms.

``branch 'wt/<platform>' already exists``
    A worktree for this platform already exists (check ``wt.sh list``), or an
    old branch was kept after removing one. Remove the worktree, or delete
    the branch with ``git branch -d wt/<platform>``.

``'...' is not writable — cannot create ...``
    You are inside the build container. Exit it and run the command from
    your host shell.

``... has uncommitted changes beyond local.conf — refusing to remove``
    See `Removing a worktree`_.
