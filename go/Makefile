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

.PHONY: clean-caddy-src

clean-caddy-src:
	find caddy/caddy/ -type f -exec sed -i.bak "s'github.com/mholt/caddy'github.com/inverse-inc/packetfence/go/caddy/caddy'g" {} \; ; find . -name '*.bak' -delete
	find caddy/caddy/ -name '*_test.go' -delete
