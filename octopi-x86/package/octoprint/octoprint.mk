################################################################################
#
# octoprint
#
################################################################################

OCTOPRINT_VERSION = 1.10.2
OCTOPRINT_SOURCE = OctoPrint-$(OCTOPRINT_VERSION).tar.gz
OCTOPRINT_SITE = https://files.pythonhosted.org/packages/source/O/OctoPrint
OCTOPRINT_SETUP_TYPE = setuptools
OCTOPRINT_LICENSE = AGPL-3.0
OCTOPRINT_LICENSE_FILES = LICENSE.txt

OCTOPRINT_DEPENDENCIES = \
    python3 \
    python-pip \
    python-setuptools \
    python-wheel \
    libffi \
    openssl

# Install OctoPrint and all its Python dependencies via pip
# This is cleaner than tracking every dep as a Buildroot package
define OCTOPRINT_INSTALL_TARGET_CMDS
    $(HOST_DIR)/bin/pip3 install \
        --prefix="$(TARGET_DIR)/usr" \
        --no-build-isolation \
        OctoPrint==$(OCTOPRINT_VERSION)
endef

# Install the systemd service and wrapper script
define OCTOPRINT_INSTALL_INIT_SYSTEMD
    $(INSTALL) -D -m 0644 \
        $(BR2_EXTERNAL_OCTOPI_PATH)/overlay/usr/lib/systemd/system/octoprint.service \
        $(TARGET_DIR)/usr/lib/systemd/system/octoprint.service
endef

$(eval $(python-package))
