include ../config.mk
GO ?= go
build_cmd = $(GO) build $(ARGS)

.PHONY: all
all: $(PF_BINARIES)

.PHONY: go-env
go-env:
	GOVERSION=$(GOVERSION) ../addons/dev-helpers/setup-go-env.sh

.PHONY: test
test:
	/usr/local/pf/t/pfconfig-test ;\
	PFCONFIG_PROTO=unix PFCONFIG_TESTING=y $(GO) test -count=1 ./...

CMDS = $(wildcard cmd/*)
ALL_BINARIES = $(patsubst cmd/%, %, $(CMDS))
.PHONY: $(ALL_BINARIES)
$(ALL_BINARIES):
	$(build_cmd) -C cmd/$@ -o ../../$@

ALL_BINARIES_RACE = $(patsubst cmd/%, %-race, $(CMDS))
$(ALL_BINARIES_RACE):
	$(build_cmd) -C cmd/$(@:-race=) -o ../../$@ -race

.PHONY: copy
copy:
	cp -f $(PF_BINARIES) $(DESTDIR)$(SBINDIR)
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
