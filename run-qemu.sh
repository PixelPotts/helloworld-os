#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DISKIMG="$SCRIPT_DIR/disk/helloworld.img"
OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.fd"
OVMF_VARS="/usr/share/OVMF/OVMF_VARS_4M.fd"
OVMF_VARS_COPY="$SCRIPT_DIR/disk/OVMF_VARS_4M.fd"

if [ ! -f "$DISKIMG" ]; then
    echo "Error: $DISKIMG not found. Run 'make disk' first."
    exit 1
fi

# Create a writable copy of OVMF vars (QEMU needs RW for NVRAM)
if [ ! -f "$OVMF_VARS_COPY" ]; then
    cp "$OVMF_VARS" "$OVMF_VARS_COPY"
fi

echo "Launching QEMU — simulating i5-14400F / 64GB / UEFI..."
echo "Press Ctrl+Alt+G to release mouse, Ctrl+C in terminal to kill"
echo ""

exec qemu-system-x86_64 \
    -machine q35,accel=kvm \
    -cpu host \
    -smp cores=10 \
    -m 4G \
    \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$OVMF_VARS_COPY" \
    \
    -drive file="$DISKIMG",format=raw,if=virtio \
    \
    -net none \
    -vga std \
    -serial stdio
