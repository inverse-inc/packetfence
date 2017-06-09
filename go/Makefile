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

go_dhcpd:
	cd dhcp && \
	go build && \
	mv dhcp ../../sbin/go_dhcpd

.PHONY: clean-caddy-src

clean-caddy-src:
	find caddy/caddy/ -type f -exec sed -i.bak "s'github.com/mholt/caddy'github.com/inverse-inc/packetfence/go/caddy/caddy'g" {} \; ; find . -name '*.bak' -delete
	find caddy/caddy/ -name '*_test.go' -delete

.PHONY: go-env

go-env:
	/usr/local/pf/addons/dev-helpers/setup-go-env.sh

.PHONY: test

test:
	/usr/local/pf/t/pfconfig-test ;\
	PFCONFIG_TESTING=y govendor test ./... ;\
	pkill pfconfig-test
