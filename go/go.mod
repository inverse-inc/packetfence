module github.com/inverse-inc/packetfence/go

go 1.17

require (
	github.com/Azure/azure-sdk-for-go v40.6.0+incompatible
	github.com/Azure/go-autorest/autorest v0.11.10
	github.com/Azure/go-autorest/autorest/adal v0.9.5
	github.com/Azure/go-autorest/autorest/azure/auth v0.5.3
	github.com/OneOfOne/xxhash v1.2.7
	github.com/Sereal/Sereal v0.0.0-20200729022450-08708a3c86f3
	github.com/armon/go-socks5 v0.0.0-20160902184237-e75332964ef5
	github.com/aws/aws-sdk-go v1.35.9
	github.com/captncraig/cors v0.0.0-20170507232344-153f484dcf3d
	github.com/cenkalti/backoff/v4 v4.1.0
	github.com/coredns/caddy v1.1.0
	github.com/coreos/go-systemd v0.0.0-20190719114852-fd7a80b32e1f
	github.com/davecgh/go-spew v1.1.1
	github.com/dnstap/golang-dnstap v0.2.2
	github.com/dustin/go-humanize v1.0.0
	github.com/farsightsec/golang-framestream v0.3.0
	github.com/fdurand/arp v0.0.0-20180807174648-27b38d3af1be
	github.com/fdurand/go-cache v0.0.0-20180104143916-cf0198ac7d92
	github.com/flynn/go-shlex v0.0.0-20150515145356-3f9db97f8568
	github.com/fsnotify/fsnotify v1.4.9
	github.com/gdey/jsonpath v0.0.0-20151203210429-124c978a1ffc
	github.com/gin-gonic/gin v1.7.0
	github.com/go-acme/lego v2.5.0+incompatible
	github.com/go-errors/errors v1.0.1
	github.com/go-kit/kit v0.10.0
	github.com/go-redis/redis v0.0.0-20190325112110-a679e614427a
	github.com/go-sql-driver/mysql v1.6.0
	github.com/goji/httpauth v0.0.0-20160601135302-2da839ab0f4d
	github.com/golang/protobuf v1.5.2
	github.com/google/go-cmp v0.5.5
	github.com/google/uuid v1.1.1
	github.com/gorilla/mux v1.7.3
	github.com/gorilla/rpc v0.0.0-20160927134711-22c016f3df3f
	github.com/gorilla/schema v1.1.0
	github.com/gorilla/websocket v1.4.2
	github.com/grpc-ecosystem/grpc-opentracing v0.0.0-20180507213350-8e809c8a8645
	github.com/hashicorp/go-syslog v1.0.0
	github.com/hpcloud/tail v1.0.0
	github.com/inconshreveable/log15 v0.0.0-20171019012758-0decfc6c20d9
	github.com/infobloxopen/go-trees v0.0.0-20190313150506-2af4e13f9062
	github.com/inverse-inc/dhcp4 v0.0.0-20200625173842-2c4d1e50d7ca
	github.com/inverse-inc/go-ipset/v2 v2.2.4
	github.com/inverse-inc/go-radius v0.0.0-20201019132414-82756e2d8d47
	github.com/inverse-inc/go-utils v0.0.0-20210420024101-48a17e73abae
	github.com/inverse-inc/scep v0.0.0-20220616202131-aafda39f7dd7
	github.com/jcuga/golongpoll v1.1.0
	github.com/jimstudt/http-authentication v0.0.0-20140401203705-3eca13d6893a
	github.com/jinzhu/gorm v1.9.16
	github.com/jpillora/backoff v1.0.0
	github.com/jpillora/requestlog v1.0.0
	github.com/jpillora/sizestr v1.0.0
	github.com/julienschmidt/httprouter v1.3.0
	github.com/julsemaan/certmagic v0.6.3-0.20191015203349-067e102ae4ff
	github.com/klauspost/cpuid v1.2.1
	github.com/knq/pemutil v0.0.0-20181215144041-fb6fad722528
	github.com/kylelemons/godebug v0.0.0-20170820004349-d65d576e9348 // indirect
	github.com/lucas-clemente/quic-go v0.10.2
	github.com/matttproud/golang_protobuf_extensions v1.0.1
	github.com/mdlayher/ethernet v0.0.0-20170707213343-e72cf8343052
	github.com/mdlayher/raw v0.0.0-20171214195253-9df8b4265df2
	github.com/mediocregopher/radix.v2 v0.0.0-20180603022615-94360be26253
	github.com/miekg/dns v1.1.34
	github.com/naoina/toml v0.1.1
	github.com/nu7hatch/gouuid v0.0.0-20131221200532-179d4d0c4d8d
	github.com/nxadm/tail v1.4.8
	github.com/opentracing/opentracing-go v1.2.0
	github.com/openzipkin-contrib/zipkin-go-opentracing v0.4.5
	github.com/openzipkin/zipkin-go v0.2.2
	github.com/patrickmn/go-cache v2.1.0+incompatible
	github.com/phayes/freeport v0.0.0-20220201140144-74d24b5ae9f5
	github.com/prometheus/client_golang v1.8.0
	github.com/prometheus/client_model v0.2.0
	github.com/prometheus/common v0.14.0
	github.com/robfig/cron/v3 v3.0.1
	github.com/russross/blackfriday v1.5.2
	github.com/simon/go-netadv v0.0.0-20170602081515-fe67988531c7
	github.com/sparrc/go-ping v0.0.0-20190613174326-4e5b6552494c
	github.com/ti-mo/netfilter v0.2.0
	golang.org/x/crypto v0.0.0-20210921155107-089bfa567519
	golang.org/x/net v0.0.0-20210614182718-04defd469f4e
	golang.org/x/sync v0.0.0-20210220032951-036812b2e83c
	golang.org/x/sys v0.0.0-20211216021012-1d35b9e2eb4e
	golang.org/x/text v0.3.6
	google.golang.org/api v0.29.0
	google.golang.org/grpc v1.29.1
	gopkg.in/DataDog/dd-trace-go.v1 v1.27.1
	gopkg.in/alexcesaro/statsd.v2 v2.0.0-20160320182110-7fea3f0d2fab
	gopkg.in/gomail.v2 v2.0.0-20160411212932-81ebce5c23df
	gopkg.in/ldap.v2 v2.0.0-20171123045618-bb7a9ca6e4fb
	gopkg.in/natefinch/lumberjack.v2 v2.0.0
	gopkg.in/yaml.v2 v2.4.0
	k8s.io/api v0.19.2
	k8s.io/apimachinery v0.19.2
	k8s.io/client-go v0.19.2
	k8s.io/klog v1.0.0
	software.sslmate.com/src/go-pkcs12 v0.0.0-20190322163127-6e380ad96778
)

require (
	cloud.google.com/go v0.56.0 // indirect
	github.com/Azure/go-autorest v14.2.0+incompatible // indirect
	github.com/Azure/go-autorest/autorest/azure/cli v0.4.2 // indirect
	github.com/Azure/go-autorest/autorest/date v0.3.0 // indirect
	github.com/Azure/go-autorest/logger v0.2.0 // indirect
	github.com/Azure/go-autorest/tracing v0.6.0 // indirect
	github.com/beorn7/perks v1.0.1 // indirect
	github.com/bifurcation/mint v0.0.0-20180715133206-93c51c6ce115 // indirect
	github.com/cenkalti/backoff v2.2.1+incompatible // indirect
	github.com/cespare/xxhash/v2 v2.1.2 // indirect
	github.com/cevaris/ordered_map v0.0.0-20171019141434-01ce2b16ad4f // indirect
	github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f // indirect
	github.com/dimchansky/utfbom v1.1.0 // indirect
	github.com/evanphx/json-patch v4.9.0+incompatible // indirect
	github.com/form3tech-oss/jwt-go v3.2.2+incompatible // indirect
	github.com/gin-contrib/sse v0.1.0 // indirect
	github.com/go-logfmt/logfmt v0.5.0 // indirect
	github.com/go-logr/logr v0.2.0 // indirect
	github.com/go-playground/locales v0.13.0 // indirect
	github.com/go-playground/universal-translator v0.17.0 // indirect
	github.com/go-playground/validator/v10 v10.4.1 // indirect
	github.com/go-stack/stack v1.8.0 // indirect
	github.com/gogo/protobuf v1.3.1 // indirect
	github.com/golang/groupcache v0.0.0-20200121045136-8c9f03a8e57e // indirect
	github.com/google/gofuzz v1.1.0 // indirect
	github.com/googleapis/gax-go/v2 v2.0.5 // indirect
	github.com/googleapis/gnostic v0.4.1 // indirect
	github.com/groob/finalizer v0.0.0-20170707115354-4c2ed49aabda // indirect
	github.com/inverse-inc/pkcs7 v0.0.0-20210506124822-140ab7b963b3 // indirect
	github.com/jinzhu/inflection v1.0.0 // indirect
	github.com/jmespath/go-jmespath v0.4.0 // indirect
	github.com/json-iterator/go v1.1.10 // indirect
	github.com/kr/pretty v0.2.1 // indirect
	github.com/kr/text v0.1.0 // indirect
	github.com/leodido/go-urn v1.2.0 // indirect
	github.com/lucas-clemente/aes12 v0.0.0-20171027163421-cd47fb39b79f // indirect
	github.com/lucas-clemente/quic-go-certificates v0.0.0-20160823095156-d2f86524cced // indirect
	github.com/mattn/go-colorable v0.1.8 // indirect
	github.com/mattn/go-isatty v0.0.12 // indirect
	github.com/mdlayher/netlink v0.0.0-20190313131330-258ea9dff42c // indirect
	github.com/mitchellh/go-homedir v1.1.0 // indirect
	github.com/modern-go/concurrent v0.0.0-20180306012644-bacd9c7ef1dd // indirect
	github.com/modern-go/reflect2 v1.0.1 // indirect
	github.com/opentracing-contrib/go-observer v0.0.0-20170622124052-a52f23424492 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	github.com/prometheus/procfs v0.2.0 // indirect
	github.com/spf13/pflag v1.0.5 // indirect
	github.com/tinylib/msgp v1.1.2 // indirect
	github.com/ugorji/go/codec v1.1.7 // indirect
	go.opencensus.io v0.22.3 // indirect
	golang.org/x/oauth2 v0.0.0-20200107190931-bf48bf16ab8d // indirect
	golang.org/x/time v0.0.0-20191024005414-555d28b269f0 // indirect
	golang.org/x/xerrors v0.0.0-20191204190536-9bdfabe68543 // indirect
	google.golang.org/appengine v1.6.5 // indirect
	google.golang.org/genproto v0.0.0-20200526211855-cb27e3aa2013 // indirect
	gopkg.in/fsnotify.v1 v1.4.7 // indirect
	gopkg.in/inf.v0 v0.9.1 // indirect
	gopkg.in/tomb.v1 v1.0.0-20141024135613-dd632973f1e7 // indirect
	k8s.io/klog/v2 v2.2.0 // indirect
	k8s.io/kube-openapi v0.0.0-20200805222855-6aeccd4b50c6 // indirect
	k8s.io/utils v0.0.0-20200729134348-d5654de09c73 // indirect
	sigs.k8s.io/structured-merge-diff/v4 v4.0.1 // indirect
	sigs.k8s.io/yaml v1.2.0 // indirect
)

require (
	github.com/Azure/go-autorest/autorest/to v0.2.0 // indirect
	github.com/DataDog/datadog-go v3.5.0+incompatible // indirect
	github.com/DataDog/zstd v1.4.5 // indirect
	github.com/andrew-d/go-termutil v0.0.0-20150726205930-009166a695a2 // indirect
	github.com/cheekybits/genny v1.0.0 // indirect
	github.com/go-redis/redis/v8 v8.11.5
	github.com/golang/snappy v0.0.1 // indirect
	github.com/hashicorp/golang-lru v0.5.4 // indirect
	github.com/imdario/mergo v0.3.9 // indirect
	github.com/jpillora/ansi v1.0.2 // indirect
	github.com/kylelemons/godebug v0.0.0-20170820004349-d65d576e9348 // indirect
	github.com/naoina/go-stringutil v0.1.0 // indirect
	github.com/philhofer/fwd v1.0.0 // indirect
	github.com/tomasen/realip v0.0.0-20180522021738-f0c99a92ddce // indirect
	golang.org/x/term v0.0.0-20210615171337-6886f2dfbf5b // indirect
	google.golang.org/protobuf v1.28.0 // indirect
	gopkg.in/alexcesaro/quotedprintable.v3 v3.0.0-20150716171945-2caba252f4dc // indirect
	gopkg.in/asn1-ber.v1 v1.0.0-20181015200546-f715ec2f112d // indirect
	gopkg.in/square/go-jose.v2 v2.3.1 // indirect
)

replace github.com/inverse-inc/packetfence => ../

replace github.com/inverse-inc/packetfence/go => ./

replace github.com/inverse-inc/packetfence/go/caddy/caddy => ./go/caddy/caddy
