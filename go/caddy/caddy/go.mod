module github.com/inverse-inc/packetfence/go/caddy/caddy

go 1.12

require (
	github.com/coreos/go-systemd v0.0.0-20190719114852-fd7a80b32e1f
	github.com/dustin/go-humanize v1.0.0
	github.com/flynn/go-shlex v0.0.0-20150515145356-3f9db97f8568
	github.com/go-acme/lego v2.5.0+incompatible
	github.com/google/uuid v1.1.1
	github.com/gorilla/websocket v1.4.0
	github.com/hashicorp/go-syslog v1.0.0
	github.com/hashicorp/golang-lru v0.0.0-20180201235237-0fb14efe8c47 // indirect
	github.com/inverse-inc/packetfence/go v0.0.0-00010101000000-000000000000
	github.com/jimstudt/http-authentication v0.0.0-20140401203705-3eca13d6893a
	github.com/klauspost/cpuid v1.2.0
	github.com/kylelemons/godebug v0.0.0-20170820004349-d65d576e9348 // indirect
	github.com/lucas-clemente/quic-clients v0.1.0 // indirect
	github.com/lucas-clemente/quic-go v0.11.0
	github.com/mholt/certmagic v0.6.2-0.20190624175158-6a42ef9fe8c2
	github.com/naoina/go-stringutil v0.1.0 // indirect
	github.com/naoina/toml v0.1.1
	github.com/onsi/ginkgo v1.8.0 // indirect
	github.com/onsi/gomega v1.5.0 // indirect
	github.com/russross/blackfriday v1.5.2
	golang.org/x/net v0.0.0-20190404232315-eb5bcb51f2a3
	gopkg.in/mcuadros/go-syslog.v2 v2.2.1
	gopkg.in/natefinch/lumberjack.v2 v2.0.0
	gopkg.in/yaml.v2 v2.2.2
)

replace github.com/inverse-inc/packetfence/go => ../../
