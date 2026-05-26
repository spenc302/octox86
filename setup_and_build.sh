#!/bin/bash
# ============================================================
#  setup_and_build.sh
#  Run this inside WSL2 on Windows 11 to build the OctoPi x86 image
#  
#  First time setup (~30 min downloads, 2-4 hour build):
#    bash setup_and_build.sh
#
#  Subsequent builds (much faster):
#    bash setup_and_build.sh --build-only
# ============================================================

set -e

BUILDROOT_VERSION="2024.11.1"
BUILDROOT_DIR="${HOME}/buildroot-${BUILDROOT_VERSION}"
OCTOPI_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${HOME}/octopi-x86-output"
BUILD_ONLY=false

# Parse args
for arg in "$@"; do
    case $arg in
        --build-only) BUILD_ONLY=true ;;
    esac
done

section() { echo -e "\n\033[1;32m========== $1 ==========\033[0m\n"; }
info()    { echo -e "\033[0;32m[INFO]\033[0m $1"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m $1"; }

# ---- Step 1: Install build dependencies ----
if [ "$BUILD_ONLY" = false ]; then
    section "Installing Build Dependencies"
    sudo apt-get update
    sudo apt-get install -y \
        build-essential \
        gcc \
        g++ \
        make \
        patch \
        wget \
        curl \
        git \
        cpio \
        unzip \
        rsync \
        bc \
        libncurses-dev \
        libssl-dev \
        python3 \
        python3-pip \
        bison \
        flex \
        file \
        genimage \
        mtools \
        dosfstools \
        e2fsprogs \
        parted \
        grub-efi-ia32-bin   # <-- provides bootia32.efi for the build
    info "Dependencies installed"

    # ---- Step 2: Download Buildroot ----
    section "Downloading Buildroot ${BUILDROOT_VERSION}"
    if [ ! -d "${BUILDROOT_DIR}" ]; then
        wget -c \
            "https://buildroot.org/downloads/buildroot-${BUILDROOT_VERSION}.tar.gz" \
            -O /tmp/buildroot.tar.gz
        tar -xf /tmp/buildroot.tar.gz -C "${HOME}"
        info "Buildroot extracted to ${BUILDROOT_DIR}"
    else
        info "Buildroot already downloaded, skipping"
    fi
fi

# ---- Step 3: Configure Buildroot ----
section "Configuring Buildroot"
mkdir -p "${OUTPUT_DIR}"

# Apply your custom defconfig target
make -C "${BUILDROOT_DIR}" \
    BR2_EXTERNAL="${OCTOPI_DIR}" \
    O="${OUTPUT_DIR}" \
    computestick_defconfig

# Automatically clean out, migrate, and resolve legacy/invalid symbols
make -C "${BUILDROOT_DIR}" \
    BR2_EXTERNAL="${OCTOPI_DIR}" \
    O="${OUTPUT_DIR}" \
    olddefconfig

info "Configuration applied and legacy settings normalized"

# ---- Step 4: Build ----
section "Building OctoPi x86 Image"
warn "This will take 2-4 hours on first run."
warn "Subsequent builds are much faster (incremental)."
echo ""

# Use all available cores
CORES=$(nproc)
info "Building with ${CORES} CPU cores..."

make -C "${BUILDROOT_DIR}" \
    BR2_EXTERNAL="${OCTOPI_DIR}" \
    O="${OUTPUT_DIR}" \
    -j${CORES}

# ---- Step 5: Done ----
section "Build Complete!"

IMAGE="${OUTPUT_DIR}/images/octopi-x86.img"

if [ -f "${IMAGE}" ]; then
    # Copy image to Windows-accessible location
    WIN_DESKTOP=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')/Desktop" 2>/dev/null || echo "")
    
    if [ -n "${WIN_DESKTOP}" ] && [ -d "${WIN_DESKTOP}" ]; then
        cp "${IMAGE}" "${WIN_DESKTOP}/octopi-x86.img"
        info "Image copied to Windows Desktop: octopi-x86.img"
    fi

    SIZE=$(du -sh "${IMAGE}" | cut -f1)
    echo ""
    echo "  Image location: ${IMAGE}"
    echo "  Image size:     ${SIZE}"
    echo ""
    echo "  Flash with Rufus on Windows:"
    echo "  1. Open Rufus"
    echo "  2. Select octopi-x86.img"
    echo "  3. Select your USB drive"
    echo "  4. Write in DD Image mode"
    echo ""
    echo "  BEFORE first boot:"
    echo "  → Open the USB in Windows Explorer"
    echo "  → Edit octopi-wpa-supplicant.txt with your WiFi SSID and password"
    echo ""
    echo "  After booting Compute Stick:"
    echo "  → Open browser on any device on same WiFi"
    echo "  → Go to: http://octopi.local"
    echo ""
else
    echo "ERROR: Image not found at ${IMAGE}"
    echo "Check build output above for errors."
    exit 1
fi