#!/bin/bash
# ============================================================
#  post-image.sh — Assembles flashable octopi-x86.img
#  Uses dd + parted + rsync directly (no genimage)
# ============================================================
set -e

BOARD_DIR="$(dirname "$0")"
BINARIES_DIR="${BINARIES_DIR}"
TARGET_DIR="${TARGET_DIR}"
IMAGE="${BINARIES_DIR}/octopi-x86.img"

echo ">>> post-image: Assembling flashable image..."

EFI_SIZE=64
ROOT_SIZE=3072
TOTAL_SIZE=$((EFI_SIZE + ROOT_SIZE + 2))

# Create blank image
dd if=/dev/zero of="${IMAGE}" bs=1M count=${TOTAL_SIZE} status=progress

# Partition table
sudo parted -s "${IMAGE}" \
    mklabel gpt \
    mkpart ESP fat32 1MiB $((EFI_SIZE + 1))MiB \
    set 1 esp on \
    mkpart root ext4 $((EFI_SIZE + 1))MiB 100%

# Mount via loop device
LOOP=$(sudo losetup --find --show --partscan "${IMAGE}")
echo ">>> Loop device: ${LOOP}"

# Format
sudo mkfs.vfat -F 32 -n "octopi-boot" "${LOOP}p1"
sudo mkfs.ext4 -L "octopi-root" "${LOOP}p2"

# Populate EFI partition
EFI_MOUNT=$(mktemp -d)
sudo mount "${LOOP}p1" "${EFI_MOUNT}"
sudo mkdir -p "${EFI_MOUNT}/EFI/BOOT"
sudo mkdir -p "${EFI_MOUNT}/grub"

GRUB_EFI=$(find /usr/lib/grub /usr/share/grub -name "*.efi" 2>/dev/null | grep -i ia32 | head -1)
if [ -z "${GRUB_EFI}" ]; then
    GRUB_EFI=$(find / -name "bootia32.efi" 2>/dev/null | head -1)
fi
if [ -n "${GRUB_EFI}" ]; then
    sudo cp "${GRUB_EFI}" "${EFI_MOUNT}/EFI/BOOT/bootia32.efi"
    echo ">>> bootia32.efi from: ${GRUB_EFI}"
else
    echo "ERROR: bootia32.efi not found"
    sudo umount "${EFI_MOUNT}"
    sudo losetup -d "${LOOP}"
    exit 1
fi

sudo cp "${BINARIES_DIR}/bzImage" "${EFI_MOUNT}/vmlinuz"
sudo cp "${BOARD_DIR}/grub.cfg" "${EFI_MOUNT}/grub/grub.cfg"
sudo cp "${BOARD_DIR}/../../overlay/boot/octopi-wpa-supplicant.txt" \
    "${EFI_MOUNT}/octopi-wpa-supplicant.txt"

sudo umount "${EFI_MOUNT}"
rmdir "${EFI_MOUNT}"

# Populate root partition
ROOT_MOUNT=$(mktemp -d)
sudo mount "${LOOP}p2" "${ROOT_MOUNT}"
echo ">>> Copying rootfs..."
sudo rsync -aH "${TARGET_DIR}/" "${ROOT_MOUNT}/"
sudo umount "${ROOT_MOUNT}"
rmdir "${ROOT_MOUNT}"

sudo losetup -d "${LOOP}"

echo ""
echo ">>> post-image: SUCCESS!"
ls -lh "${IMAGE}"
