include ../config.mk

.PHONY: clean-caddy-src
clean-caddy-src:
	find caddy/ -type f -exec sed -i.bak "s'github.com/mholt/caddy'github.com/inverse-inc/packetfence/go/caddy/caddy'g" {} \; ; find . -name '*.bak' -delete
	find caddy/ -type f -exec sed -i.bak "s'github.com/caddyserver/caddy'github.com/inverse-inc/packetfence/go/caddy/caddy'g" {} \; ; find . -name '*.bak' -delete
	find caddy/caddy/ -name '*_test.go' -delete

.PHONY: go-env
go-env:
	GOVERSION=$(GOVERSION) ../addons/dev-helpers/setup-go-env.sh

.PHONY: test
test:
	/usr/local/pf/t/pfconfig-test ;\
	PFCONFIG_TESTING=y go test -count=1 ./...

CMDS = $(wildcard cmd/*)
ALL_BINARIES = $(patsubst cmd/%, %, $(CMDS))
.PHONY: $(ALL_BINARIES)
$(ALL_BINARIES):
	cd cmd/$@ && \
	go build && \
	mv $@ ../..

ALL_BINARIES_RACE = $(patsubst cmd/%, %-race, $(CMDS))
$(ALL_BINARIES_RACE):
	cd cmd/$(@:-race=) && \
	go build -o $@ -race && \
	mv $@ ../..

.PHONY: all
all: $(PF_BINARIES)

.PHONY: copy
copy:
	cp -f $(PF_BINARIES) $(DESTDIR)$(SBINDIR)

.PHONY: clean
clean:
	rm -f $(PF_BINARIES)

.PHONY: clean-coredns-src
clean-coredns-src:
	find coredns/ -type f -exec sed -i.bak "s'github.com/mholt/caddy'github.com/inverse-inc/packetfence/go/caddy/caddy'g" {} \; ; find . -name '*.bak' -delete
	find coredns/ -type f -exec sed -i.bak "s'github.com/coredns/coredns'github.com/inverse-inc/packetfence/go/coredns'g" {} \; ; find . -name '*.bak' -delete
	find coredns/ -name '*_test.go' -delete
