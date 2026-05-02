#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EFI="$SCRIPT_DIR/build/hello.efi"

usage() {
    echo "Usage: $0 /dev/sdX"
    echo ""
    echo "Writes a GPT + ESP + FAT32 partition with BOOTX64.EFI to a USB drive."
    echo "WARNING: This will DESTROY ALL DATA on the target device!"
    exit 1
}

if [ $# -ne 1 ]; then
    usage
fi

DEV="$1"

# Safety checks
if [ ! -b "$DEV" ]; then
    echo "Error: $DEV is not a block device."
    exit 1
fi

if [ ! -f "$EFI" ]; then
    echo "Error: $EFI not found. Run 'make' first."
    exit 1
fi

# Refuse to write to system disks
ROOTDEV=$(findmnt -no SOURCE / | sed 's/[0-9]*$//' | sed 's/p[0-9]*$//')
if [ "$DEV" = "$ROOTDEV" ]; then
    echo "Error: $DEV appears to be your root disk. Refusing."
    exit 1
fi

# Check if the device is mounted
if mount | grep -q "^${DEV}"; then
    echo "Error: $DEV or a partition on it is currently mounted. Unmount first."
    exit 1
fi

echo "======================================"
echo "  Target device: $DEV"
echo "  EFI payload:   $EFI"
echo ""
echo "  ALL DATA ON $DEV WILL BE DESTROYED"
echo "======================================"
echo ""
read -rp "Type YES to continue: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
    echo "Aborted."
    exit 1
fi

echo "Creating GPT partition table..."
sudo sgdisk --zap-all "$DEV"
sudo sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:"EFI System" "$DEV"
sudo partprobe "$DEV"
sleep 1

# Detect partition name (sdX1 or sdXp1)
if [ -b "${DEV}1" ]; then
    PART="${DEV}1"
elif [ -b "${DEV}p1" ]; then
    PART="${DEV}p1"
else
    echo "Error: Could not find partition on $DEV"
    exit 1
fi

echo "Formatting $PART as FAT32..."
sudo mkfs.fat -F32 -n "HELLOWORLD" "$PART"

echo "Mounting and copying EFI payload..."
MOUNT_DIR=$(mktemp -d)
sudo mount "$PART" "$MOUNT_DIR"
sudo mkdir -p "$MOUNT_DIR/EFI/BOOT"
sudo cp "$EFI" "$MOUNT_DIR/EFI/BOOT/BOOTX64.EFI"
sudo umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"

echo ""
echo "Done! USB drive is ready."
echo "Boot your machine, press F12 (or DEL), and select the USB drive."
echo "You should see 'Hello, World!' from your UEFI OS."
