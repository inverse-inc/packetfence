.PHONY: iso clean upload

# Default values
PF_VERSION ?= $(shell cut -d' ' -f2 < ../../conf/pf-release)
PF_RELEASE ?= $(shell cat ../../conf/pf-release)
ISO_OUT ?= PacketFence-USB-ISO-$(PF_VERSION).iso

# Export for sub-scripts
export PF_VERSION
export PF_RELEASE
export ISO_OUT

# Build ISO only (no upload)
iso:
	./build-usb-bootable-iso.sh

# Build and upload ISO
upload:
	./build-and-upload.sh

clean:
	chmod -R +w work/ isofiles/ 2>/dev/null || true
	rm -rf work/ results/ *.iso *.md5 isofiles/ pool/ dists/ docker-images/
