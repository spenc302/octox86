#!/bin/bash
# ============================================================
#  post-build.sh
#  Runs after Buildroot assembles the rootfs, before image creation
#  Installs OctoPrint via pip into the target rootfs
# ============================================================
set -e

TARGET=$1
BOARD_DIR="$(dirname "$0")"
OCTOPRINT_VERSION="1.10.2"

echo ">>> post-build: Installing OctoPrint ${OCTOPRINT_VERSION} into rootfs..."

# Install OctoPrint and dependencies using target's pip
# We use PYTHONPATH tricks to install into the target rootfs
${HOST_DIR}/bin/python3 -m pip install \
    --target="${TARGET}/usr/lib/python3/dist-packages" \
    --no-deps \
    OctoPrint==${OCTOPRINT_VERSION} \
    2>/dev/null || true

# Better approach: use pip with target prefix
${HOST_DIR}/bin/pip3 install \
    --prefix="${TARGET}/usr" \
    --ignore-installed \
    OctoPrint==${OCTOPRINT_VERSION} \
    Flask \
    Jinja2 \
    PyYAML \
    requests \
    tornado \
    netaddr \
    pathvalidate \
    psutil \
    frozendict \
    click \
    watchdog \
    markdown \
    feedparser \
    sarge \
    netifaces \
    blinker \
    cachelib \
    pydantic || echo "Warning: pip install via host may need manual completion"

echo ">>> post-build: Configuring system..."

# Set root filesystem label (used by GRUB)
echo "octopi" > "${TARGET}/etc/hostname"

# Enable serial device access for octoprint user
mkdir -p "${TARGET}/etc/udev/rules.d"
cat > "${TARGET}/etc/udev/rules.d/99-octoprint-serial.rules" << 'EOF'
# Grant octoprint user access to USB serial devices (3D printers)
SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", GROUP="dialout", MODE="0664"  # CH340/CH341
SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", GROUP="dialout", MODE="0664"  # CP210x
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", GROUP="dialout", MODE="0664"  # FTDI
SUBSYSTEM=="tty", ATTRS{idVendor}=="2341", GROUP="dialout", MODE="0664"  # Arduino
EOF

# Create octoprint user and group
echo "octoprint:x:1000:1000:OctoPrint,,,:/home/octoprint:/bin/bash" >> "${TARGET}/etc/passwd"
echo "octoprint:x:1000:" >> "${TARGET}/etc/group"
echo "dialout:x:20:octoprint" >> "${TARGET}/etc/group"
mkdir -p "${TARGET}/home/octoprint"

# Enable required systemd services
mkdir -p "${TARGET}/etc/systemd/system/multi-user.target.wants"
mkdir -p "${TARGET}/etc/systemd/system/network-online.target.wants"

ln -sf /usr/lib/systemd/system/octoprint.service \
    "${TARGET}/etc/systemd/system/multi-user.target.wants/octoprint.service"
ln -sf /usr/lib/systemd/system/haproxy.service \
    "${TARGET}/etc/systemd/system/multi-user.target.wants/haproxy.service"
ln -sf /usr/lib/systemd/system/avahi-daemon.service \
    "${TARGET}/etc/systemd/system/multi-user.target.wants/avahi-daemon.service"
ln -sf /usr/lib/systemd/system/wpa_supplicant.service \
    "${TARGET}/etc/systemd/system/multi-user.target.wants/wpa_supplicant.service"
ln -sf /usr/lib/systemd/system/octopi-firstboot.service \
    "${TARGET}/etc/systemd/system/multi-user.target.wants/octopi-firstboot.service"

echo ">>> post-build: Done."
