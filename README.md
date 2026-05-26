# OctoPi x86
### A custom Linux OS for the Intel Compute Stick STCK1A32WFC
#### Built with Buildroot — modelled on OctoPi for Raspberry Pi

---

## What This Is

A purpose-built, minimal Linux image that turns the Intel Compute Stick into a
dedicated OctoPrint server. Nothing more, nothing less — like OctoPi but for x86.

**Included:**
- Linux kernel (configured for Bay Trail + RTL8723BS WiFi)
- OctoPrint (latest stable)
- HAProxy (routes port 80 → OctoPrint on 5000)
- Avahi (makes device reachable at `octopi.local`)
- wpa_supplicant (WiFi)
- OpenSSH (remote access)
- ~200MB total image size

**Not included:**
- Desktop environment
- mjpg-streamer (USB port dedicated to printer)
- Anything else

---

## Requirements

- Windows 11 laptop with **WSL2** installed
- Intel Compute Stick STCK1A32WFC
- USB drive (8GB+)
- USB keyboard (only needed for initial flash, not ongoing use)

### Install WSL2 (if not already installed)
Open PowerShell as Administrator and run:
```
wsl --install
```
Then restart your PC and open the Ubuntu app from the Start menu.

---

## Build Instructions

```bash
# In WSL2 terminal:
git clone <this repo>   # or copy the octopi-x86 folder into WSL
cd octopi-x86
bash setup_and_build.sh
```

First build: **2–4 hours** (compiling everything from source)  
Subsequent builds: **5–15 minutes** (incremental)

The finished image (`octopi-x86.img`) will be copied to your Windows Desktop automatically.

---

## Flash & First Boot

1. Open **Rufus** on Windows
2. Select `octopi-x86.img` and your USB drive
3. Write in **DD Image mode**
4. After flashing, **open the USB drive in Windows Explorer**
5. Edit `octopi-wpa-supplicant.txt` — fill in your WiFi SSID and password
6. Safely eject USB
7. Plug into Compute Stick, power on
8. Wait ~60 seconds for first boot
9. Open browser on any device on same WiFi → `http://octopi.local`

---

## Accessing the Device

| Method | Address |
|--------|---------|
| Web UI | http://octopi.local |
| Web UI (IP) | http://\<device-ip\> |
| SSH | `ssh octoprint@octopi.local` |

Default SSH password: `octoprint`  
**Change it after first login:** `passwd`

---

## 3D Printer Connection

Plug your printer into the USB port. In OctoPrint's setup wizard:

- **Serial port:** `/dev/ttyUSB0` (most printers) or `/dev/ttyACM0`
- **Baud rate:** 115200 (Marlin default) or 250000

---

## Project Structure

```
octopi-x86/
├── setup_and_build.sh          # One-shot build script for WSL2
├── computestick_defconfig      # Buildroot configuration
├── Config.in                   # BR2_EXTERNAL package menu
├── external.mk                 # BR2_EXTERNAL package inclusion
├── external.desc               # BR2_EXTERNAL description
├── board/computestick/
│   ├── linux.config            # Kernel config (Bay Trail optimised)
│   ├── grub.cfg                # GRUB bootloader config (32-bit EFI)
│   ├── grub-builtin.cfg        # GRUB built-in config fragment
│   ├── genimage.cfg            # Disk image layout (EFI + rootfs)
│   ├── post-build.sh           # Runs after rootfs assembly
│   └── post-image.sh           # Creates final .img
├── overlay/                    # Files dropped into rootfs
│   ├── boot/
│   │   └── octopi-wpa-supplicant.txt   # WiFi setup (user edits)
│   ├── etc/
│   │   ├── haproxy/haproxy.cfg
│   │   └── avahi/services/octoprint.service
│   └── usr/
│       ├── sbin/octopi-firstboot.sh
│       └── lib/systemd/system/
│           ├── octoprint.service
│           └── octopi-firstboot.service
└── package/octoprint/
    ├── Config.in
    └── octoprint.mk
```

---

## Rebuilding After Changes

```bash
# In WSL2, from octopi-x86 directory:
bash setup_and_build.sh --build-only
```

To update OctoPrint version: edit `OCTOPRINT_VERSION` in `package/octoprint/octoprint.mk`

---

## Troubleshooting

**Compute Stick won't boot**  
→ Rufus must write in DD mode, not ISO mode  
→ Verify GRUB ia32 EFI is present: USB should have `EFI/BOOT/bootia32.efi`

**WiFi not connecting**  
→ Check `octopi-wpa-supplicant.txt` on the boot partition — SSID/password must be exact  
→ SSH into device via ethernet (USB adapter) and check: `journalctl -u wpa_supplicant`

**Printer not detected**  
→ Run `ls /dev/tty*` before and after plugging printer  
→ Make sure printer firmware is running (some boards need to be powered on separately)

**OctoPrint won't start**  
→ Check: `journalctl -u octoprint -f`
