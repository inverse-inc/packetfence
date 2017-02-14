.PHONY: processor-sha

pfcaddy-sha:
	make NAME="pfcaddy" _pfcaddy

pfcaddy:
	make NAME="pfcaddy" _pfcaddy

_pfcaddy:
	cd caddy/caddy/caddy && \
	go build && \
	cd - && \
	mv caddy/caddy/caddy/caddy ${NAME}

.PHONY: clean-caddy-src

clean-caddy-src:
	find caddy/caddy/ -type f -exec sed -i.bak "s'github.com/mholt/caddy'github.com/inverse-inc/packetfence/go/caddy/caddy'g" {} \; ; find . -name '*.bak' -delete
	find caddy/caddy/ -name '*_test.go'
