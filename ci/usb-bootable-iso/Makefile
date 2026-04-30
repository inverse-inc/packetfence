.PHONY: iso upload clean stage1 stage2 stage3 help

# Default values
PF_VERSION ?= $(shell cut -d' ' -f2 < ../../conf/pf-release)
PF_RELEASE ?= $(shell cat ../../conf/pf-release)
ISO_OUT ?= PacketFence-USB-ISO-$(PF_VERSION).iso

# Export for sub-scripts
export PF_VERSION
export PF_RELEASE
export ISO_OUT

# Build ISO only (no upload). Runs the full containerized pipeline:
# stage 0 (host wget) -> stage 1 (host docker pull) ->
# stage 2 (debian:bookworm: debootstrap + apt) -> stage 3 (debian:bookworm: xorriso)
iso:
	./build-usb-bootable-iso.sh

# Build and upload ISO to Linode (CI target)
upload:
	./build-and-upload.sh

# Run individual build stages (for debugging). Each stage assumes the
# previous ones have already produced their outputs in work/.
stage1:
	./step1-pull-docker-images.sh

stage2:
	./step2-create-local-repo.sh

stage3:
	./step3-assemble-iso.sh

clean:
	chmod -R +w work/ isofiles/ 2>/dev/null || true
	rm -rf work/ results/ *.iso *.md5 isofiles/ pool/ dists/ docker-images/

help:
	@echo "Targets:"
	@echo "  iso      Build the USB bootable ISO (full pipeline)"
	@echo "  upload   Build and upload the ISO to Linode (CI target)"
	@echo "  stage1   Stage 1: pre-pull Docker images (host)"
	@echo "  stage2   Stage 2: build offline APT repo (in debian:bookworm)"
	@echo "  stage3   Stage 3: assemble final ISO (in debian:bookworm)"
	@echo "  clean    Remove all build artifacts"
	@echo ""
	@echo "Useful overrides:"
	@echo "  PF_VERSION=...        Override the PacketFence version"
	@echo "  ISO_OUT=...           Output ISO path"
	@echo "  BUILDER_IMAGE=...     Override builder image (default: debian:bookworm)"
	@echo "  SKIP_CLEAN=1          Keep work/ between builds (faster rebuilds)"
