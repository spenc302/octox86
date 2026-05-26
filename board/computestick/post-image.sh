#!/bin/bash
# ============================================================
#  post-image.sh
#  Assembles the final flashable octopi-x86.img using genimage
# ============================================================
set -e

BOARD_DIR="$(dirname "$0")"
GENIMAGE_CFG="${1:-${BOARD_DIR}/genimage.cfg}"
BINARIES_DIR="${BINARIES_DIR}"
BUILD_DIR="${BUILD_DIR}"

echo ">>> post-image: Assembling flashable image..."

# Copy GRUB config and kernel to binaries dir for genimage to find
cp "${BOARD_DIR}/grub.cfg" "${BINARIES_DIR}/grub.cfg"

# Set up EFI directory structure for genimage
mkdir -p "${BINARIES_DIR}/EFI/BOOT"
cp "${BINARIES_DIR}/efi-part/EFI/BOOT/bootia32.efi" \
   "${BINARIES_DIR}/EFI/BOOT/bootia32.efi"

# Set up grub directory
mkdir -p "${BINARIES_DIR}/grub"
cp "${BOARD_DIR}/grub.cfg" "${BINARIES_DIR}/grub/grub.cfg"

# Copy kernel and initrd
cp "${BINARIES_DIR}/bzImage" "${BINARIES_DIR}/vmlinuz"

# Copy the WiFi setup template to boot partition
cp "${BOARD_DIR}/../../overlay/boot/octopi-wpa-supplicant.txt" \
   "${BINARIES_DIR}/octopi-wpa-supplicant.txt"

# Label the root filesystem
e2label "${BINARIES_DIR}/rootfs.ext4" "octopi-root" || true

# Clean genimage tmp dir
rm -rf "${BUILD_DIR}/genimage.tmp"

# Run genimage
genimage \
    --rootpath "${TARGET_DIR}" \
    --tmppath  "${BUILD_DIR}/genimage.tmp" \
    --inputpath "${BINARIES_DIR}" \
    --outputpath "${BINARIES_DIR}" \
    --config "${GENIMAGE_CFG}"

echo ""
echo ">>> post-image: SUCCESS!"
echo "    Flashable image: ${BINARIES_DIR}/octopi-x86.img"
echo ""
echo "    Flash to USB on Windows:"
echo "    → Use Rufus or Win32DiskImager"
echo "    → Select octopi-x86.img and your USB drive"
echo ""
echo "    BEFORE FIRST BOOT:"
echo "    → Open the USB drive in Windows Explorer"
echo "    → Edit octopi-wpa-supplicant.txt with your WiFi credentials"
echo ""
