#!/bin/bash

if [ $# -ne 1 ]; then
	echo "Please provide the board name (virt32, virt64, rpi4, rpi4_64)"
	exit 0
fi

# Partition layout on the sdcard:
# - Partition #1: 128 MB (u-boot, kernel, etc.)
# - Partition #2: 180 MB (agency main rootfs)

if [ "$1" == "virt32" -o "$1" == "virt64"  ]; then
    #create image first
    echo Creating sdcard.img.$1 ...
    dd_size=450M
    dd if=/dev/zero of=sdcard.img.$1 bs="$dd_size" count=1
    disk_loop=$(sudo losetup --partscan --find --show sdcard.img.$1)


    # Keep device name only without /dev/
    devname=${disk_loop#"/dev/"}
fi

if [ "$1" == "rpi4" -o "$1" == "rpi4_64" ]; then
    echo "Specify the MMC device you want to deploy on (ex: sdb or mmcblk0 or other...)"
    read devname
fi

# Ensure that the device isn't mounted before creating the image, doesn't call ./umount.sh to avoid remove the disk loopback
export devname=$devname
while mounted_dev=$(mount -l | grep -E "/dev/($(echo $devname | sed 's/ /|/g'))" | sed -n 's/^\(\/dev\/[^ ]*\).*$/\1/p') && [ "$mounted_dev" != "" ]; do
    # Ensure that nothing is using a file in mounted device
    while lsof +f -- ${mounted_dev}; do
        echo "Waiting for target to be unbusy"
        sleep 0.5
    done

    sudo umount ${mounted_dev}
done

if [ "$1" == "virt32" -o "$1" == "rpi4" -o "$1" == "rpi4_64" -o "$1" == "virt64" ]; then
# Create the partition layout this way
    (echo o; echo n; echo p; echo; echo; echo +128M; echo t; echo c; echo n; echo p; echo; echo; echo; echo w)   | sudo fdisk /dev/"$devname";
fi

# Give a chance to the real SD-card to be sync'd
sleep 1s

if [[ "$devname" = *[0-9] ]]; then
    export devname="${devname}p"
fi

sudo mkfs.fat -n POS-BOOT -F32 -v /dev/"$devname"1
sudo mkfs.ext4 -L POS-ROOTFS /dev/"$devname"2

if [ "$1" == "virt32" -o "$1" == "virt64" ]; then
    sudo losetup --detach $disk_loop
fi
