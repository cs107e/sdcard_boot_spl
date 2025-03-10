#!/bin/bash -ex
#
# Install binary program into boot sector of sdcard
#

# this is the version of boot0 with EGON header attached
BINARY=nboot/boot0_sdcard_sun20iw1p1.bin

BSIZE=`stat -f%z $BINARY`
if [ $BSIZE -gt 65535 ]; then   # required to be < 64K
    echo "$BINARY ($BSIZE bytes) size too large!"
    exit 1
fi

echo "Available external disks:"
diskutil list external
echo "Review above list to find the one you intend (should be FAT32)"
read -p "Enter disk dev path: " SDCARD

diskutil unmountDisk $SDCARD  # need to unmount before dd
echo "note: sudo-dd may require password"
sudo dd if=$BINARY of=$SDCARD bs=8192 seek=16 # copy boot0 to bootsector

diskutil mountDisk $SDCARD  # mount disk, rename, populate with README & sample image
FAT_PARTITION="${SDCARD}s1"
diskutil rename $FAT_PARTITION MPIBOOT
cp README-sdcard.txt /Volumes/MPIBOOT/README.txt
if [ ! -f /Volumes/MPIBOOT/MANGO.BIN ]; then
    cp $CS107E/bin/blink-actled.bin /Volumes/MPIBOOT/MANGO.BIN
fi
echo "Here are contents of SD card"
ls -l /Volumes/MPIBOOT

diskutil unmountDisk $SDCARD  # unmount after write so able to eject
