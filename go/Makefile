include ../config.mk
GO ?= go
CGO_ENABLED=1
# to change the arch a binary is compiled for.
# make GOARCH=arm64 pfconnector
GOARCH=
# NOTE: $(ARGS) is expanded after -C in the build recipes (go requires -C to
# be the first flag).
build_cmd = CGO_ENABLED=$(CGO_ENABLED) $(if $(GOARCH),GOARCH=$(GOARCH),) $(GO) build

.PHONY: all
all: $(PF_BINARIES) $(PF_GO_CMDS)

.PHONY: go-env
go-env:
	GOVERSION=$(GOVERSION) ../addons/dev-helpers/setup-go-env.sh

.PHONY: test
test:
	/usr/local/pf/t/pfconfig-test ;\
	GODEBUG=randseednop=0 PF_SYSTEM_INIT_KEY=$$(cat ../t/data/system_init_key) PFCONFIG_PROTO=unix PFCONFIG_TESTING=y $(GO) test -count=1 ./...

CMDS = $(wildcard cmd/*)
ALL_BINARIES = $(patsubst cmd/%, %, $(CMDS))
.PHONY: $(ALL_BINARIES)

pfconnector: CGO_ENABLED=0
# Embed the PF release as the connector build version (reported by the
# admin UI remote status panel). Falls back to the in-source default
# (0.0.0-src) when conf/pf-release isn't available.
pfconnector: ARGS += $(if $(PF_PATCH_RELEASE),-ldflags "-X github.com/inverse-inc/packetfence/go/chisel/share.BuildVersion=$(PF_PATCH_RELEASE)")

$(ALL_BINARIES):
	$(build_cmd) -C cmd/$@ $(ARGS) -o ../../$@

ALL_BINARIES_RACE = $(patsubst cmd/%, %-race, $(CMDS))
$(ALL_BINARIES_RACE):
	$(build_cmd) -C cmd/$(@:-race=) $(ARGS) -o ../../$@ -race

.PHONY: copy
copy: copy-sbin copy-bin

.PHONY: copy-sbin
copy-sbin: $(PF_BINARIES)
	cp -f $(PF_BINARIES) $(DESTDIR)$(SBINDIR)

.PHONY: copy-bin
copy-bin: $(PF_GO_CMDS)
	cp -f $(PF_GO_CMDS) $(DESTDIR)$(BINDIR)

.PHONY: clean
clean:
	rm -f $(PF_BINARIES) $(PF_GO_CMDS)

.PHONY: clean-coredns-src
clean-coredns-src:
	find coredns/ -type f -exec sed -i.bak "s'github.com/mholt/caddy'github.com/inverse-inc/packetfence/go/caddy/caddy'g" {} \; ; find . -name '*.bak' -delete
	find coredns/ -type f -exec sed -i.bak "s'github.com/coredns/coredns'github.com/inverse-inc/packetfence/go/coredns'g" {} \; ; find . -name '*.bak' -delete
	find coredns/ -name '*_test.go' -delete

.PHONY: clean-chisel-src
clean-chisel-src:
	find chisel/ -type f -exec sed -i.bak "s'github.com/jpillora/chisel'github.com/inverse-inc/packetfence/go/chisel'g" {} \; ; find . -name '*.bak' -delete
