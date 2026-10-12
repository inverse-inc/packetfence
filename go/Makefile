include ../config.mk
GO ?= go
CGO_ENABLED=1
# to change the arch a binary is compiled for.
# make GOARCH=arm64 pfconnector
GOARCH=
build_cmd = CGO_ENABLED=$(CGO_ENABLED) $(if $(GOARCH),GOARCH=$(GOARCH),) $(GO) build $(ARGS)

# Pin analyzers independently of the application's module dependencies.
STATICCHECK_VERSION = v0.8.1
GOVULNCHECK_VERSION = v1.8.0
GOSEC_VERSION = v2.28.0
# Check the whole module on the build host, including packages requiring cgo.
# Do not inherit pfconnector's CGO_ENABLED=0 or cross-compilation settings.
check_cmd = CGO_ENABLED=1 GOOS= GOARCH= $(GO)

.PHONY: all
all: $(PF_BINARIES) $(PF_GO_CMDS)

# vet gates the build. The other three are advisory: they report a known backlog
# (see docs) that must be triaged before their leading `-` can be dropped.
.PHONY: check
check:
	$(check_cmd) vet ./...
	-$(check_cmd) run honnef.co/go/tools/cmd/staticcheck@$(STATICCHECK_VERSION) -tests -show-ignored ./...
	-$(check_cmd) run golang.org/x/vuln/cmd/govulncheck@$(GOVULNCHECK_VERSION) ./...
	-$(check_cmd) run github.com/securego/gosec/v2/cmd/gosec@$(GOSEC_VERSION) ./...

.PHONY: go-env
go-env:
	GOVERSION=$(GOVERSION) ../addons/dev-helpers/setup-go-env.sh

.PHONY: test
test:
	[ -s /usr/local/pf/var/run/pfconfig-test.pid ] &&  kill $$(cat /usr/local/pf/var/run/pfconfig-test.pid);\
	/usr/local/pf/t/pfconfig-test ;\
	GODEBUG=randseednop=0 PF_SYSTEM_INIT_KEY=$$(cat ../t/data/system_init_key) PFCONFIG_PROTO=unix PFCONFIG_TESTING=y $(GO) test -count=1 ./...

CMDS = $(wildcard cmd/*)
ALL_BINARIES = $(patsubst cmd/%, %, $(CMDS))
.PHONY: $(ALL_BINARIES)

pfconnector: CGO_ENABLED=0

$(ALL_BINARIES): check
	$(build_cmd) -C cmd/$@ -o ../../$@

ALL_BINARIES_RACE = $(patsubst cmd/%, %-race, $(CMDS))
.PHONY: $(ALL_BINARIES_RACE)
$(ALL_BINARIES_RACE): check
	$(build_cmd) -C cmd/$(@:-race=) -o ../../$@ -race

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
