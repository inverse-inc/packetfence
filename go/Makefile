include ../config.mk

.PHONY: pfdhcp
pfdhcp:
	cd dhcp && \
	go build && \
	cd - && \
	mv dhcp/dhcp pfdhcp

.PHONY: pfdns
pfdns:
	cd coredns && \
	go build && \
	cd - && \
	mv coredns/coredns pfdns

.PHONY: pfstats
pfstats:
	cd stats && \
        go build && \
        cd - && \
        mv stats/stats pfstats

.PHONY: pfdetect
pfdetect:
	cd detect && \
        go build && \
        cd - && \
        mv detect/detect pfdetect

.PHONY: galera-autofix
galera-autofix:
	cd galeraautofix && \
        go build && \
        cd - && \
        mv galeraautofix/galeraautofix galera-autofix

.PHONY: pfacct
pfacct:
	cd acct && \
        go build && \
        cd - && \
        mv acct/acct pfacct

.PHONY: radius-tester
radius-tester:
	cd acct-tester/radius-tester && \
	go build && \
	cd - && \
	mv acct-tester/radius-tester/radius-tester radius-tester

.PHONY: pfcertmanager
pfcertmanager:
	cd certmanager && \
        go build && \
        cd - && \
        mv certmanager/certmanager pfcertmanager

.PHONY: db-tester
db-tester:
	cd acct-tester/db-tester && \
	go build && \
	cd - && \
	mv acct-tester/db-tester/db-tester db-tester

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
BINARYS = $(patsubst cmd/%, %, $(CMDS))
.PHONY: $(BINARYS)
$(BINARYS):
	cd cmd/$@ && \
	go build && \
	mv $@ ../..

BINARYS_RACE = $(patsubst cmd/%, %-race, $(CMDS))
$(BINARYS_RACE):
	cd cmd/$(@:-race=) && \
	go build -o $@ -race && \
	mv $@ ../..

.PHONY: all
all: $(GOBINARIES)

.PHONY: copy
copy:
	cp -f $(GOBINARIES) $(DESTDIR)$(SBINDIR)

.PHONY: clean
clean:
	rm -f $(GOBINARIES)

.PHONY: clean-coredns-src
clean-coredns-src:
	find coredns/ -type f -exec sed -i.bak "s'github.com/mholt/caddy'github.com/inverse-inc/packetfence/go/caddy/caddy'g" {} \; ; find . -name '*.bak' -delete
	find coredns/ -type f -exec sed -i.bak "s'github.com/coredns/coredns'github.com/inverse-inc/packetfence/go/coredns'g" {} \; ; find . -name '*.bak' -delete
	find coredns/ -name '*_test.go' -delete
