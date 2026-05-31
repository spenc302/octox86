#!/bin/bash
# ============================================================
#  octopi-firstboot.sh
#  Reads WiFi credentials from the boot partition on first boot
#  Falls back gracefully if WiFi is already baked in
# ============================================================

WIFI_CONFIG_SRC="/boot/octopi-wpa-supplicant.txt"
WPA_CONFIG="/etc/wpa_supplicant/wpa_supplicant-wlan0.conf"
DONE_FLAG="/etc/octopi-firstboot-done"

if [ -f "${DONE_FLAG}" ]; then
    exit 0
fi

echo "OctoPi: Running first-boot setup..."

if [ -f "${WIFI_CONFIG_SRC}" ]; then
    if grep -q "Your_Network_Name" "${WIFI_CONFIG_SRC}"; then
        echo "OctoPi: Boot partition WiFi file has placeholder values - skipping."
        echo "OctoPi: Using baked-in WiFi credentials."
    else
        echo "OctoPi: Applying WiFi config from boot partition..."
        cat > "${WPA_CONFIG}" << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=CA

EOF
        grep -v "^##" "${WIFI_CONFIG_SRC}" | grep -v "^$" >> "${WPA_CONFIG}"
        echo "OctoPi: WiFi configuration applied."

        systemctl restart wpa_supplicant@wlan0 || true

        echo "OctoPi: Waiting for WiFi connection..."
        for i in $(seq 1 30); do
            if wpa_cli -i wlan0 status 2>/dev/null | grep -q "wpa_state=COMPLETED"; then
                echo "OctoPi: WiFi connected."
                break
            fi
            sleep 1
        done
    fi
else
    echo "OctoPi: No boot partition WiFi file found - using baked-in credentials."
fi

touch "${DONE_FLAG}"
exit 0
