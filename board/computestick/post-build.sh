#!/bin/bash
# ============================================================
#  post-build.sh
#  Runs after Buildroot assembles the rootfs, before image creation
# ============================================================
set -e

TARGET=$1
BOARD_DIR="$(dirname "$0")"

echo ">>> post-build: Configuring system..."

# Set hostname
echo "octopi" > "${TARGET}/etc/hostname"

# Create octoprint user and group
if ! grep -q "^octoprint:" "${TARGET}/etc/passwd" 2>/dev/null; then
    echo "octoprint:x:1000:1000:OctoPrint,,,:/home/octoprint:/bin/sh" \
        >> "${TARGET}/etc/passwd"
fi
if ! grep -q "^octoprint:" "${TARGET}/etc/group" 2>/dev/null; then
    echo "octoprint:x:1000:" >> "${TARGET}/etc/group"
fi
if ! grep -q "^dialout:" "${TARGET}/etc/group" 2>/dev/null; then
    echo "dialout:x:20:octoprint" >> "${TARGET}/etc/group"
else
    sed -i 's/^dialout:x:20:.*/dialout:x:20:octoprint/' "${TARGET}/etc/group"
fi

mkdir -p "${TARGET}/home/octoprint"

# udev rules for printer USB serial access
mkdir -p "${TARGET}/etc/udev/rules.d"
cat > "${TARGET}/etc/udev/rules.d/99-octoprint-serial.rules" << 'EOF'
SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", GROUP="dialout", MODE="0664"
SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", GROUP="dialout", MODE="0664"
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", GROUP="dialout", MODE="0664"
SUBSYSTEM=="tty", ATTRS{idVendor}=="2341", GROUP="dialout", MODE="0664"
EOF

# First-boot OctoPrint installer script
# Runs once on device to install OctoPrint via pip
cat > "${TARGET}/usr/sbin/octopi-install-octoprint.sh" << 'INSTALLEOF'
#!/bin/sh
# Installs OctoPrint on first boot
DONE_FLAG="/etc/octoprint-installed"
if [ -f "${DONE_FLAG}" ]; then exit 0; fi

echo "OctoPi: Installing OctoPrint (first boot - please wait)..."
pip3 install --break-system-packages OctoPrint==1.10.2
touch "${DONE_FLAG}"
echo "OctoPi: OctoPrint installed successfully."
INSTALLEOF
chmod +x "${TARGET}/usr/sbin/octopi-install-octoprint.sh"

# Systemd service to install OctoPrint on first boot
cat > "${TARGET}/usr/lib/systemd/system/octoprint-install.service" << 'EOF'
[Unit]
Description=OctoPrint First Boot Installer
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/etc/octoprint-installed

[Service]
Type=oneshot
ExecStart=/usr/sbin/octopi-install-octoprint.sh
ExecStartPost=/bin/systemctl enable octoprint.service
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable required systemd services
mkdir -p "${TARGET}/etc/systemd/system/multi-user.target.wants"

ln -sf /usr/lib/systemd/system/octoprint-install.service \
    "${TARGET}/etc/systemd/system/multi-user.target.wants/octoprint-install.service"
ln -sf /usr/lib/systemd/system/haproxy.service \
    "${TARGET}/etc/systemd/system/multi-user.target.wants/haproxy.service"
ln -sf /usr/lib/systemd/system/avahi-daemon.service \
    "${TARGET}/etc/systemd/system/multi-user.target.wants/avahi-daemon.service"
ln -sf /usr/lib/systemd/system/wpa_supplicant.service \
    "${TARGET}/etc/systemd/system/multi-user.target.wants/wpa_supplicant.service"
ln -sf /usr/lib/systemd/system/octopi-firstboot.service \
    "${TARGET}/etc/systemd/system/multi-user.target.wants/octopi-firstboot.service"

echo ">>> post-build: Done."

