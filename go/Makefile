GOVERSION=go1.9.3

.PHONY: processor-sha

pfhttpd-sha:
	make NAME="pfhttpd" _pfhttpd

pfhttpd:
	make NAME="pfhttpd" _pfhttpd

_pfhttpd:
	cd caddy/caddy/caddy && \
	go build && \
	cd - && \
	mv caddy/caddy/caddy/caddy ${NAME}

pfhttpd-race:
	cd caddy/caddy/caddy && \
	go build -race && \
	cd - && \
	mv caddy/caddy/caddy/caddy pfhttpd-race

pfdhcp:
	cd dhcp && \
	go build && \
	cd - && \
	mv dhcp/dhcp pfdhcp

pfdns:
	cd coredns && \
	go build && \
	cd - && \
	mv coredns/coredns pfdns

pfstats:
	cd stats && \
        go build && \
        cd - && \
        mv stats/stats pfstats

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
	/usr/local/pf/addons/dev-helpers/setup-go-env.sh $(GOVERSION)

.PHONY: test

test:
	/usr/local/pf/t/pfconfig-test ;\
	PFCONFIG_TESTING=y govendor test ./...

all: pfhttpd pfdhcp pfdns pfstats pfdetect

copy:
	cp -f pfhttpd pfdhcp pfdns pfstats pfdetect /usr/local/pf/sbin/

.PHONY: clean-coredns-src

clean-coredns-src:
	find coredns/ -type f -exec sed -i.bak "s'github.com/mholt/caddy'github.com/inverse-inc/packetfence/go/caddy/caddy'g" {} \; ; find . -name '*.bak' -delete
	find coredns/ -type f -exec sed -i.bak "s'github.com/coredns/coredns'github.com/inverse-inc/packetfence/go/coredns'g" {} \; ; find . -name '*.bak' -delete
	find coredns/ -name '*_test.go' -delete
