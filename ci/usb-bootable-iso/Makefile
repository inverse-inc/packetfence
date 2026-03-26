PF_VERSION=$(CI_COMMIT_REF_NAME)
RESULT_DIR=results

.PHONY: iso
iso:
	echo "Building PacketFence USB Bootable ISO for $(PF_VERSION)"
	PF_RELEASE='$(shell cat ../../conf/pf-release)' \
	PF_VERSION='$(PF_VERSION)' \
	 ./build-and-upload.sh

.PHONY: local
local:
	echo "Building PacketFence USB Bootable ISO locally"
	PF_RELEASE='$(shell cat ../../conf/pf-release)' \
	PF_VERSION='localtest' \
	ISO_OUT='PacketFence-USB-Bootable-localtest.iso' \
	 ./build-usb-bootable-iso.sh

.PHONY: clean
clean:
	rm -rf $(RESULT_DIR)
	rm -rf build
	rm -f PacketFence-USB-Bootable-*.iso*
