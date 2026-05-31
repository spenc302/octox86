################################################################################
#
# octoprint
#
################################################################################

OCTOPRINT_VERSION = 1.10.2
OCTOPRINT_LICENSE = AGPL-3.0

# This package is a stub — OctoPrint is installed on first boot
# via /usr/sbin/octopi-install-octoprint.sh using pip3 on the device.
# This avoids cross-compilation issues with the host pip3.

define OCTOPRINT_INSTALL_TARGET_CMDS
	# intentionally empty — first-boot installer handles this
endef

$(eval $(generic-package))
