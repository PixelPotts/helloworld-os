#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EFI="$SCRIPT_DIR/build/hello.efi"
ESP="/boot/efi"
DEST_DIR="$ESP/EFI/helloworld"
DEST="$DEST_DIR/hello.efi"
ENTRY_LABEL="HelloWorld OS"

# --- Helpers ---
die() { echo "Error: $*" >&2; exit 1; }

show_status() {
    echo ""
    echo "Current UEFI boot config:"
    efibootmgr
    echo ""
}

# --- Preflight ---
[ -f "$EFI" ] || die "build/hello.efi not found. Run 'make' first."
[ -d "$ESP/EFI" ] || die "EFI System Partition not mounted at $ESP"
command -v efibootmgr >/dev/null || die "efibootmgr not installed"

case "${1:-}" in
    install)
        echo "=== Installing HelloWorld OS to ESP ==="
        echo ""
        echo "  Source: $EFI"
        echo "  Dest:   $DEST"
        echo ""
        echo "This will:"
        echo "  1. Copy hello.efi to $DEST_DIR/"
        echo "  2. Add a UEFI boot entry '$ENTRY_LABEL'"
        echo "  3. Set it as ONE-TIME next boot (--bootnext)"
        echo ""
        echo "Your existing boot entries will NOT be modified."
        echo "After one reboot, your machine boots Ubuntu as normal."
        echo ""
        read -rp "Continue? [y/N] " ans
        [ "$ans" = "y" ] || [ "$ans" = "Y" ] || { echo "Aborted."; exit 0; }

        # Copy EFI binary
        sudo mkdir -p "$DEST_DIR"
        sudo cp "$EFI" "$DEST"
        echo "Copied hello.efi to ESP."

        # Find the ESP disk and partition number
        ESP_DEV=$(findmnt -no SOURCE "$ESP")  # e.g. /dev/sda2
        DISK=$(echo "$ESP_DEV" | sed 's/[0-9]*$//')  # e.g. /dev/sda
        PARTNUM=$(echo "$ESP_DEV" | grep -o '[0-9]*$')  # e.g. 2

        # Check if entry already exists
        EXISTING=$(efibootmgr | grep "$ENTRY_LABEL" | grep -o 'Boot[0-9]*' | grep -o '[0-9]*' || true)
        if [ -n "$EXISTING" ]; then
            echo "Boot entry $EXISTING already exists, reusing it."
            BOOTNUM="$EXISTING"
        else
            # Create new UEFI boot entry
            sudo efibootmgr --create \
                --disk "$DISK" \
                --part "$PARTNUM" \
                --label "$ENTRY_LABEL" \
                --loader '\EFI\helloworld\hello.efi' \
                --quiet
            BOOTNUM=$(efibootmgr | grep "$ENTRY_LABEL" | grep -o 'Boot[0-9]*' | grep -o '[0-9]*' | head -1)
            echo "Created boot entry: Boot$BOOTNUM"
        fi

        # Set as one-time next boot
        sudo efibootmgr --bootnext "$BOOTNUM" --quiet
        echo "Set Boot$BOOTNUM as next boot (one-time only)."

        show_status
        echo "=== Ready! ==="
        echo "Reboot now to see 'Hello, World!' on real hardware."
        echo "Press any key in the OS to shut down."
        echo "Next boot after that → Ubuntu as normal."
        echo ""
        echo "To reboot now:  sudo reboot"
        echo "To undo first:  $0 remove"
        ;;

    remove)
        echo "=== Removing HelloWorld OS from ESP ==="

        # Find and remove boot entry
        BOOTNUM=$(efibootmgr | grep "$ENTRY_LABEL" | grep -o 'Boot[0-9]*' | grep -o '[0-9]*' || true)
        if [ -n "$BOOTNUM" ]; then
            sudo efibootmgr --bootnum "$BOOTNUM" --delete-bootnum --quiet
            echo "Removed boot entry Boot$BOOTNUM."
        else
            echo "No boot entry found for '$ENTRY_LABEL'."
        fi

        # Clear bootnext if it was set
        sudo efibootmgr --delete-bootnext --quiet 2>/dev/null || true

        # Remove files
        if [ -d "$DEST_DIR" ]; then
            sudo rm -rf "$DEST_DIR"
            echo "Removed $DEST_DIR/"
        fi

        show_status
        echo "=== Cleanup complete. Everything back to normal. ==="
        ;;

    status)
        show_status
        [ -f "$DEST" ] && echo "hello.efi is installed at $DEST" || echo "hello.efi is NOT installed on ESP"
        BOOTNEXT=$(efibootmgr | grep "BootNext:" | awk '{print $2}' || true)
        if [ -n "$BOOTNEXT" ]; then
            echo "BootNext is set to: $BOOTNEXT (will boot once, then revert)"
        else
            echo "BootNext is not set (normal boot order active)"
        fi
        ;;

    *)
        echo "Usage: $0 {install|remove|status}"
        echo ""
        echo "  install  — Copy hello.efi to ESP, add boot entry, set one-time boot"
        echo "  remove   — Remove hello.efi and boot entry, restore normal boot"
        echo "  status   — Show current boot config and install state"
        ;;
esac
