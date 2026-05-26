#!/bin/bash
# ============================================================
#  octopi-firstboot.sh
#  Reads WiFi credentials from the boot partition on first boot
#  Mirrors OctoPi's octopi-wpa-supplicant.txt mechanism
# ============================================================

WIFI_CONFIG_SRC="/boot/octopi-wpa-supplicant.txt"
WPA_CONFIG="/etc/wpa_supplicant/wpa_supplicant.conf"
DONE_FLAG="/etc/octopi-firstboot-done"

# Only run once
if [ -f "${DONE_FLAG}" ]; then
    exit 0
fi

echo "OctoPi: Applying first-boot WiFi configuration..."

if [ -f "${WIFI_CONFIG_SRC}" ]; then
    # Check if user actually edited the file (not the placeholder)
    if grep -q "Your_Network_Name" "${WIFI_CONFIG_SRC}"; then
        echo "OctoPi: WARNING - WiFi config still has placeholder values."
        echo "OctoPi: Edit /boot/octopi-wpa-supplicant.txt and reboot."
    else
        # Write wpa_supplicant config
        cat > "${WPA_CONFIG}" << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

EOF
        # Append the network blocks from user config (strip comments)
        grep -v "^##" "${WIFI_CONFIG_SRC}" | grep -v "^$" >> "${WPA_CONFIG}"

        echo "OctoPi: WiFi configuration applied."
        
        # Restart wpa_supplicant to pick up new config
        systemctl restart wpa_supplicant || true
        
        # Wait for connection
        echo "OctoPi: Connecting to WiFi..."
        for i in $(seq 1 20); do
            if wpa_cli status 2>/dev/null | grep -q "wpa_state=COMPLETED"; then
                echo "OctoPi: WiFi connected."
                break
            fi
            sleep 1
        done
    fi
else
    echo "OctoPi: No WiFi config found at ${WIFI_CONFIG_SRC}"
fi

# Mark first boot as done
touch "${DONE_FLAG}"
exit 0
