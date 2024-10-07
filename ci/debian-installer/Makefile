PF_VERSION=$(CI_COMMIT_REF_NAME)
RESULT_DIR=results

.PHONY: packetfence-debian-installer.iso

iso:
	echo "Building Debian installer for $(PF_VERSION)"
	PF_RELEASE='$(shell cat ../../conf/pf-release)' \
	PF_VERSION='$(PF_VERSION)' \
	 ./build-and-upload.sh

.PHONY: clean
clean:
	rm -rf $(RESULT_DIR)

