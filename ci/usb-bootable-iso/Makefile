.PHONY: iso clean upload

# Default values
PF_VERSION ?= $(shell cat ../../conf/pf-release | cut -d' ' -f2)
PF_RELEASE ?= $(shell cat ../../conf/pf-release)
ISO_OUT ?= PacketFence-USB-ISO-$(PF_VERSION).iso

# Export for sub-scripts
export PF_VERSION
export PF_RELEASE
export ISO_OUT

iso:
	./build-and-upload.sh

clean:
	rm -rf work/ results/ *.iso *.md5 isofiles/ pool/ dists/ docker-images/

upload:
	./build-and-upload.sh
