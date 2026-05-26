#!/bin/bash
# ============================================================
#  post-image.sh — Assembles flashable octopi-x86.img
#  Uses dd + parted + mkfs directly (no genimage)
# ============================================================
set -e

BOARD_DIR="$(dirname "$0")"
BINARIES_DIR="${BINARIES_DIR}"
TARGET_DIR="${TARGET_DIR}"
IMAGE="${BINARIES_DIR}/octopi-x86.img"

echo ">>> post-image: Assembling flashable image..."

# Sizes in MiB
EFI_SIZE=64
ROOT_SIZE=3072
TOTAL_SIZE=$((EFI_SIZE + ROOT_SIZE + 2))  # +2 for GPT overhead

# Create blank image
dd if=/dev/zero of="${IMAGE}" bs=1M count=${TOTAL_SIZE} status=progress

# Partition: GPT, EFI partition + root partition
parted -s "${IMAGE}" \
    mklabel gpt \
    mkpart ESP fat32 1MiB $((EFI_SIZE + 1))MiB \
    set 1 esp on \
    mkpart root ext4 $((EFI_SIZE + 1))MiB 100%

# Mount image via loop device
LOOP=$(losetup --find --show --partscan "${IMAGE}")
echo ">>> Loop device: ${LOOP}"

# Format EFI partition (FAT32)
mkfs.vfat -F 32 -n "octopi-boot" "${LOOP}p1"

# Format root partition (ext4)
mkfs.ext4 -L "octopi-root" "${LOOP}p2"

# Mount EFI and populate it
EFI_MOUNT=$(mktemp -d)
mount "${LOOP}p1" "${EFI_MOUNT}"

# GRUB EFI structure
mkdir -p "${EFI_MOUNT}/EFI/BOOT"
mkdir -p "${EFI_MOUNT}/grub"

# Copy bootia32.efi (from grub-efi-ia32-bin installed on host)
if [ -f "${BINARIES_DIR}/efi-part/EFI/BOOT/bootia32.efi" ]; then
    cp "${BINARIES_DIR}/efi-part/EFI/BOOT/bootia32.efi" \
       "${EFI_MOUNT}/EFI/BOOT/bootia32.efi"
else
    # Fallback: find it from host grub package
    GRUB_EFI=$(find /usr/lib/grub -name "*.efi" | grep -i ia32 | head -1)
    if [ -z "${GRUB_EFI}" ]; then
        GRUB_EFI=$(find / -name "bootia32.efi" 2>/dev/null | head -1)
    fi
    if [ -n "${GRUB_EFI}" ]; then
        cp "${GRUB_EFI}" "${EFI_MOUNT}/EFI/BOOT/bootia32.efi"
        echo ">>> Used bootia32.efi from: ${GRUB_EFI}"
    else
        echo "ERROR: Could not find bootia32.efi"
        umount "${EFI_MOUNT}"
        losetup -d "${LOOP}"
        exit 1
    fi
fi

# Copy kernel and initrd
cp "${BINARIES_DIR}/bzImage" "${EFI_MOUNT}/vmlinuz"
if [ -f "${BINARIES_DIR}/initrd" ]; then
    cp "${BINARIES_DIR}/initrd" "${EFI_MOUNT}/initrd.img"
else
    touch "${EFI_MOUNT}/initrd.img"  # placeholder if no initrd
fi

# Copy GRUB config
cp "${BOARD_DIR}/grub.cfg" "${EFI_MOUNT}/grub/grub.cfg"

# Copy WiFi setup file
cp "${BOARD_DIR}/../../overlay/boot/octopi-wpa-supplicant.txt" \
   "${EFI_MOUNT}/octopi-wpa-supplicant.txt"

umount "${EFI_MOUNT}"
rmdir "${EFI_MOUNT}"

# Mount root and populate it
ROOT_MOUNT=$(mktemp -d)
mount "${LOOP}p2" "${ROOT_MOUNT}"

echo ">>> Copying rootfs to image..."
rsync -aH --exclude='/THIS_IS_NOT_YOUR_ROOT_FILESYSTEM' \
    "${TARGET_DIR}/" "${ROOT_MOUNT}/"

umount "${ROOT_MOUNT}"
rmdir "${ROOT_MOUNT}"

# Detach loop device
losetup -d "${LOOP}"

echo ""
echo ">>> post-image: SUCCESS!"
ls -lh "${IMAGE}"
echo ""
echo "    Flash with Rufus on Windows in DD Image mode"
echo "    Edit octopi-wpa-supplicant.txt on the USB before first boot"
