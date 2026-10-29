# Build third-party Debian packages, see README.md
#   make list
#   make docker-build PKG=sscep   # any host, uses the pfbuild trixie image
#   make build PKG=sscep          # on a Debian trixie host/container

SRC_ROOT_DIR := $(abspath $(CURDIR)/../..)
PFBUILD_DEB_IMG ?= ghcr.io/inverse-inc/packetfence/pfbuild-debian-trixie
PFBUILD_DEB_TAG ?= latest

.PHONY: list
list:
	@for recipe in */recipe.conf; do dirname $$recipe; done

.PHONY: check_pkg
check_pkg:
	@test -n "$(PKG)" || { echo "PKG is not set, available recipes:"; $(MAKE) -s list; exit 1; }

.PHONY: build
build: check_pkg
	./build.sh $(PKG)

.PHONY: docker-build
docker-build: check_pkg
	docker run --rm \
		-v $(SRC_ROOT_DIR):/src -w /src \
		$(PFBUILD_DEB_IMG):$(PFBUILD_DEB_TAG) \
		addons/third-party/build.sh $(PKG)

.PHONY: clean
clean:
	rm -rf $(SRC_ROOT_DIR)/build/third-party
