#!/bin/bash

echo Fetching QEMU 8.2.2
wget https://download.qemu.org/qemu-8.2.2.tar.xz

echo Extracting QEMU tar
tar xf qemu-8.2.2.tar.xz

echo Moving to its final destination
rsync -a qemu-8.2.2/* .
rm -rf qemu-8.2.2

echo Patching
patch -p1 < patches/0001-qemu.patch
patch -p1 < patches/0002-qemu.patch

echo Removing the tar file
rm qemu-8.2.2.tar.xz

