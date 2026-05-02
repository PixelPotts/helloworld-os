#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMG="$SCRIPT_DIR/disk/helloworld.img"
EFI="$SCRIPT_DIR/build/hello.efi"

if [ ! -f "$EFI" ]; then
    echo "Error: $EFI not found. Run 'make' first."
    exit 1
fi

mkdir -p "$SCRIPT_DIR/disk"

echo "Creating 64MB FAT32 disk image..."
dd if=/dev/zero of="$IMG" bs=1M count=64 status=none
mformat -i "$IMG" -F ::

echo "Copying EFI payload to /EFI/BOOT/BOOTX64.EFI..."
mmd -i "$IMG" ::/EFI
mmd -i "$IMG" ::/EFI/BOOT
mcopy -i "$IMG" "$EFI" ::/EFI/BOOT/BOOTX64.EFI

echo "Disk image ready: $IMG"
mdir -i "$IMG" ::/EFI/BOOT/
