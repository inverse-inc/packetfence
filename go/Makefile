include ../config.mk

.PHONY: pfhttpd-sha
pfhttpd-sha:
	make NAME="pfhttpd" _pfhttpd

.PHONY: pfhttpd
pfhttpd:
	make NAME="pfhttpd" _pfhttpd

.PHONY: _pfhttpd
_pfhttpd:
	cd caddy/caddy/caddy && \
	go build && \
	cd - && \
	mv caddy/caddy/caddy/caddy ${NAME}

.PHONY: pfhttpd-race
pfhttpd-race:
	cd caddy/caddy/caddy && \
	go build -race && \
	cd - && \
	mv caddy/caddy/caddy/caddy pfhttpd-race

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

.PHONY: clean-caddy-src
clean-caddy-src:
	find caddy/ -type f -exec sed -i.bak "s'github.com/mholt/caddy'github.com/inverse-inc/packetfence/go/caddy/caddy'g" {} \; ; find . -name '*.bak' -delete
	find caddy/caddy/ -name '*_test.go' -delete

.PHONY: go-env
go-env:
	GOVERSION=$(GOVERSION) ../addons/dev-helpers/setup-go-env.sh

.PHONY: test
test:
	/usr/local/pf/t/pfconfig-test ;\
	PFCONFIG_TESTING=y go test ./...

.PHONY: all
all: pfhttpd pfdhcp pfdns pfstats pfdetect

.PHONY: copy
copy:
	cp -f pfhttpd pfdhcp pfdns pfstats pfdetect $(SBINDIR)

.PHONY: clean-coredns-src
clean-coredns-src:
	find coredns/ -type f -exec sed -i.bak "s'github.com/mholt/caddy'github.com/inverse-inc/packetfence/go/caddy/caddy'g" {} \; ; find . -name '*.bak' -delete
	find coredns/ -type f -exec sed -i.bak "s'github.com/coredns/coredns'github.com/inverse-inc/packetfence/go/coredns'g" {} \; ; find . -name '*.bak' -delete
	find coredns/ -name '*_test.go' -delete
