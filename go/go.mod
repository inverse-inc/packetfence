module github.com/inverse-inc/packetfence/go

go 1.25.5

require (
	github.com/Azure/azure-sdk-for-go v68.0.0+incompatible // indirect
	github.com/Azure/go-autorest/autorest v0.11.30 // indirect
	github.com/Azure/go-autorest/autorest/adal v0.9.22 // indirect
	github.com/Azure/go-autorest/autorest/azure/auth v0.5.13 // indirect
	github.com/OneOfOne/xxhash v1.2.7
	github.com/Sereal/Sereal v0.0.0-20200729022450-08708a3c86f3
	github.com/armon/go-socks5 v0.0.0-20160902184237-e75332964ef5
	github.com/captncraig/cors v0.0.0-20170507232344-153f484dcf3d
	github.com/coredns/caddy v1.1.4-0.20250930002214-15135a999495
	github.com/coreos/go-systemd v0.0.0-20190719114852-fd7a80b32e1f
	github.com/davecgh/go-spew v1.1.2-0.20180830191138-d8f796af33cc
	github.com/dnstap/golang-dnstap v0.4.0
	github.com/farsightsec/golang-framestream v0.3.0 // indirect
	github.com/fdurand/arp v0.0.0-20180807174648-27b38d3af1be
	github.com/fdurand/go-cache v0.0.0-20180104143916-cf0198ac7d92
	github.com/flynn/go-shlex v0.0.0-20150515145356-3f9db97f8568 // indirect
	github.com/fsnotify/fsnotify v1.9.0
	github.com/gdey/jsonpath v0.0.0-20151203210429-124c978a1ffc
	github.com/gin-gonic/gin v1.9.1
	github.com/go-errors/errors v1.0.1
	github.com/go-kit/kit v0.13.0 // indirect
	github.com/go-sql-driver/mysql v1.8.1
	github.com/golang/protobuf v1.5.4 // indirect
	github.com/google/go-cmp v0.7.0
	github.com/google/uuid v1.6.0
	github.com/gorilla/mux v1.8.1
	github.com/gorilla/rpc v0.0.0-20160927134711-22c016f3df3f
	github.com/gorilla/schema v1.4.1
	github.com/gorilla/websocket v1.5.4-0.20250319132907-e064f32e3674
	github.com/grpc-ecosystem/grpc-opentracing v0.0.0-20180507213350-8e809c8a8645 // indirect
	github.com/hpcloud/tail v1.0.0
	github.com/inconshreveable/log15 v0.0.0-20171019012758-0decfc6c20d9
	github.com/infobloxopen/go-trees v0.0.0-20200715205103-96a057b8dfb9 // indirect
	github.com/inverse-inc/dhcp4 v0.0.0-20200625173842-2c4d1e50d7ca
	github.com/inverse-inc/go-ipset/v2 v2.2.4
	github.com/inverse-inc/go-radius v0.0.0-20251014220800-3f4796ad84c9
	github.com/inverse-inc/go-utils v0.0.0-20221121145914-6c624c4f08c4
	github.com/inverse-inc/scep v0.0.0-20250502184807-8e146f44db98
	github.com/jcuga/golongpoll v1.3.1
	github.com/jpillora/backoff v1.0.0
	github.com/jpillora/requestlog v1.0.0
	github.com/jpillora/sizestr v1.0.0
	github.com/julienschmidt/httprouter v1.3.0
	github.com/knq/pemutil v0.0.0-20181215144041-fb6fad722528
	github.com/kylelemons/godebug v1.1.0 // indirect
	github.com/matttproud/golang_protobuf_extensions v1.0.4 // indirect
	github.com/mdlayher/ethernet v0.0.0-20170707213343-e72cf8343052
	github.com/mdlayher/raw v0.0.0-20171214195253-9df8b4265df2
	github.com/mediocregopher/radix.v2 v0.0.0-20180603022615-94360be26253
	github.com/miekg/dns v1.1.72
	github.com/nxadm/tail v1.4.8
	github.com/opentracing/opentracing-go v1.2.0
	github.com/openzipkin-contrib/zipkin-go-opentracing v0.5.0 // indirect
	github.com/openzipkin/zipkin-go v0.4.3 // indirect
	github.com/patrickmn/go-cache v2.1.0+incompatible
	github.com/prometheus/client_golang v1.23.2
	github.com/prometheus/client_model v0.6.2 // indirect
	github.com/prometheus/common v0.67.5 // indirect
	github.com/robfig/cron/v3 v3.0.1
	github.com/simon/go-netadv v0.0.0-20170602081515-fe67988531c7
	github.com/sparrc/go-ping v0.0.0-20190613174326-4e5b6552494c
	github.com/ti-mo/netfilter v0.2.0
	golang.org/x/crypto v0.49.0
	golang.org/x/net v0.52.0
	golang.org/x/sync v0.20.0
	golang.org/x/sys v0.42.0
	golang.org/x/text v0.35.0
	google.golang.org/api v0.266.0 // indirect
	google.golang.org/grpc v1.80.0 // indirect
	gopkg.in/alexcesaro/statsd.v2 v2.0.0-20160320182110-7fea3f0d2fab
	gopkg.in/gomail.v2 v2.0.0-20160411212932-81ebce5c23df
	gopkg.in/ldap.v2 v2.0.0-20171123045618-bb7a9ca6e4fb
	gopkg.in/yaml.v2 v2.4.0
	k8s.io/api v0.34.3
	k8s.io/apimachinery v0.34.3
	k8s.io/client-go v0.34.3
	software.sslmate.com/src/go-pkcs12 v0.0.0-20190322163127-6e380ad96778
)

require (
	github.com/Azure/azure-sdk-for-go/sdk/azcore v1.21.0
	github.com/Azure/azure-sdk-for-go/sdk/azidentity v1.13.1
	github.com/VividCortex/mysqlerr v1.0.0
	github.com/go-kit/log v0.2.1
)

require github.com/coredns/coredns v1.14.1

require (
	cloud.google.com/go/compute/metadata v0.9.0 // indirect
	github.com/Azure/azure-sdk-for-go/sdk/internal v1.11.2 // indirect
	github.com/Azure/go-autorest v14.2.0+incompatible // indirect
	github.com/Azure/go-autorest/autorest/azure/cli v0.4.6 // indirect
	github.com/Azure/go-autorest/autorest/date v0.3.0 // indirect
	github.com/Azure/go-autorest/logger v0.2.1 // indirect
	github.com/Azure/go-autorest/tracing v0.6.0 // indirect
	github.com/AzureAD/microsoft-authentication-library-for-go v1.6.0 // indirect
	github.com/DataDog/datadog-agent/pkg/obfuscate v0.71.0 // indirect
	github.com/DataDog/datadog-agent/pkg/remoteconfig/state v0.73.0-rc.1 // indirect
	github.com/DataDog/datadog-go/v5 v5.6.0 // indirect
	github.com/DataDog/go-tuf v1.1.1-0.5.2 // indirect
	github.com/DataDog/sketches-go v1.4.7 // indirect
	github.com/Microsoft/go-winio v0.6.2 // indirect
	github.com/apparentlymart/go-cidr v1.1.0 // indirect
	github.com/beorn7/perks v1.0.1 // indirect
	github.com/bytedance/sonic v1.10.0 // indirect
	github.com/cespare/xxhash/v2 v2.3.0 // indirect
	github.com/cevaris/ordered_map v0.0.0-20171019141434-01ce2b16ad4f // indirect
	github.com/chenzhuoyu/base64x v0.0.0-20230717121745-296ad89f973d // indirect
	github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f // indirect
	github.com/dimchansky/utfbom v1.1.1 // indirect
	github.com/dustin/go-humanize v1.0.1 // indirect
	github.com/ebitengine/purego v0.8.4 // indirect
	github.com/emicklei/go-restful/v3 v3.12.2 // indirect
	github.com/gabriel-vasile/mimetype v1.4.2 // indirect
	github.com/gin-contrib/sse v0.1.0 // indirect
	github.com/go-chi/chi/v5 v5.2.5
	github.com/go-logfmt/logfmt v0.6.0 // indirect
	github.com/go-logr/logr v1.4.3 // indirect
	github.com/go-openapi/jsonpointer v0.21.0 // indirect
	github.com/go-openapi/jsonreference v0.20.2 // indirect
	github.com/go-openapi/swag v0.23.0 // indirect
	github.com/go-playground/locales v0.14.1 // indirect
	github.com/go-playground/universal-translator v0.18.1 // indirect
	github.com/go-playground/validator/v10 v10.15.1 // indirect
	github.com/go-stack/stack v1.8.0 // indirect
	github.com/goccy/go-json v0.10.2 // indirect
	github.com/gogo/protobuf v1.3.2 // indirect
	github.com/golang-jwt/jwt/v4 v4.5.2 // indirect
	github.com/google/pprof v0.0.0-20241210010833-40e02aabc2ad // indirect
	github.com/google/s2a-go v0.1.9 // indirect
	github.com/googleapis/enterprise-certificate-proxy v0.3.11 // indirect
	github.com/googleapis/gax-go/v2 v2.17.0 // indirect
	github.com/groob/finalizer v0.0.0-20170707115354-4c2ed49aabda // indirect
	github.com/huandu/go-clone v1.7.0 // indirect
	github.com/inverse-inc/pkcs7 v0.0.0-20221012121123-778f83870ec7 // indirect
	github.com/jinzhu/inflection v1.0.0 // indirect
	github.com/jinzhu/now v1.1.5 // indirect
	github.com/josharian/intern v1.0.0 // indirect
	github.com/json-iterator/go v1.1.12 // indirect
	github.com/klauspost/cpuid/v2 v2.3.0 // indirect
	github.com/kr/pretty v0.3.1 // indirect
	github.com/kr/text v0.2.0 // indirect
	github.com/leodido/go-urn v1.2.4 // indirect
	github.com/mailru/easyjson v0.9.0 // indirect
	github.com/mattn/go-colorable v0.1.14 // indirect
	github.com/mattn/go-isatty v0.0.20 // indirect
	github.com/mdlayher/netlink v0.0.0-20190313131330-258ea9dff42c // indirect
	github.com/mitchellh/go-homedir v1.1.0 // indirect
	github.com/modern-go/concurrent v0.0.0-20180306012644-bacd9c7ef1dd // indirect
	github.com/modern-go/reflect2 v1.0.3-0.20250322232337-35a7c28c31ee // indirect
	github.com/munnerz/goautoneg v0.0.0-20191010083416-a7dc8b61c822 // indirect
	github.com/opentracing-contrib/go-observer v0.0.0-20170622124052-a52f23424492 // indirect
	github.com/outcaste-io/ristretto v0.2.3 // indirect
	github.com/pelletier/go-toml/v2 v2.2.4 // indirect
	github.com/pkg/browser v0.0.0-20240102092130-5ac0b6a4141c // indirect
	github.com/pkg/errors v0.9.1 // indirect
	github.com/prometheus/procfs v0.19.2 // indirect
	github.com/quic-go/quic-go v0.59.0 // indirect
	github.com/rogpeppe/go-internal v1.14.1 // indirect
	github.com/secure-systems-lab/go-securesystemslib v0.9.0 // indirect
	github.com/spf13/pflag v1.0.10 // indirect
	github.com/tinylib/msgp v1.3.0 // indirect
	github.com/twitchyliquid64/golang-asm v0.15.1 // indirect
	github.com/ugorji/go/codec v1.2.11 // indirect
	go.uber.org/atomic v1.11.0 // indirect
	golang.org/x/arch v0.4.0 // indirect
	golang.org/x/exp v0.0.0-20251023183803-a4bb9ffd2546 // indirect
	golang.org/x/mod v0.33.0 // indirect
	golang.org/x/oauth2 v0.35.0 // indirect
	golang.org/x/time v0.14.0 // indirect
	golang.org/x/tools v0.42.0 // indirect
	golang.org/x/xerrors v0.0.0-20231012003039-104605ab7028 // indirect
	gopkg.in/alexcesaro/quotedprintable.v3 v3.0.0-20150716171945-2caba252f4dc // indirect
	gopkg.in/fsnotify.v1 v1.4.7 // indirect
	gopkg.in/inf.v0 v0.9.1 // indirect
	gopkg.in/tomb.v1 v1.0.0-20141024135613-dd632973f1e7 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
	k8s.io/klog/v2 v2.130.1 // indirect
	k8s.io/kube-openapi v0.0.0-20250710124328-f3f2b991d03b // indirect
	k8s.io/utils v0.0.0-20250604170112-4c0f3b243397 // indirect
	sigs.k8s.io/json v0.0.0-20241014173422-cfa47c3a1cc8 // indirect
	sigs.k8s.io/yaml v1.6.0 // indirect
)

require (
	github.com/Azure/go-autorest/autorest/to v0.2.0 // indirect
	github.com/DataDog/zstd v1.5.6 // indirect
	github.com/andrew-d/go-termutil v0.0.0-20150726205930-009166a695a2 // indirect
	github.com/golang/snappy v0.0.4 // indirect
	github.com/jpillora/ansi v1.0.2 // indirect
	github.com/philhofer/fwd v1.2.0 // indirect
	github.com/tomasen/realip v0.0.0-20180522021738-f0c99a92ddce // indirect
	golang.org/x/term v0.41.0 // indirect
	google.golang.org/protobuf v1.36.11 // indirect
	gopkg.in/asn1-ber.v1 v1.0.0-20181015200546-f715ec2f112d // indirect
)

require (
	github.com/caddyserver/caddy/v2 v2.11.2
	github.com/caddyserver/forwardproxy v0.0.0-20240314124830-ec0619230bc0
	github.com/caddyserver/transform-encoder v0.0.0-20240312163748-f627fc4f7633
	github.com/fatih/structtag v1.2.0
	github.com/go-json-experiment/json v0.0.0-20250626171732-1a886bd29d1b
	github.com/gosnmp/gosnmp v1.43.1
	github.com/huandu/go-clone/generic v1.6.0
	github.com/onsi/ginkgo/v2 v2.22.1
	github.com/onsi/gomega v1.36.2
	github.com/redis/go-redis/v9 v9.3.0
	github.com/segmentio/kafka-go v0.4.47
	github.com/smallstep/nosql v0.7.0
	go.uber.org/zap v1.27.1
	gorm.io/driver/mysql v1.5.2
	gorm.io/gorm v1.25.5
	layeh.com/radius v0.0.0-00010101000000-000000000000
)

require (
	cel.dev/expr v0.25.1 // indirect
	cloud.google.com/go/auth v0.18.1 // indirect
	cloud.google.com/go/auth/oauth2adapt v0.2.8 // indirect
	dario.cat/mergo v1.0.2 // indirect
	filippo.io/bigmod v0.1.0 // indirect
	filippo.io/edwards25519 v1.2.0 // indirect
	github.com/AndreasBriese/bbloom v0.0.0-20190825152654-46b345b51c96 // indirect
	github.com/BurntSushi/toml v1.6.0 // indirect
	github.com/DataDog/datadog-agent/comp/core/tagger/origindetection v0.71.0 // indirect
	github.com/DataDog/datadog-agent/pkg/opentelemetry-mapping-go/otlp/attributes v0.71.0 // indirect
	github.com/DataDog/datadog-agent/pkg/proto v0.71.0 // indirect
	github.com/DataDog/datadog-agent/pkg/trace v0.71.0 // indirect
	github.com/DataDog/datadog-agent/pkg/util/log v0.71.0 // indirect
	github.com/DataDog/datadog-agent/pkg/util/scrubber v0.71.0 // indirect
	github.com/DataDog/datadog-agent/pkg/version v0.71.0 // indirect
	github.com/DataDog/dd-trace-go/v2 v2.5.0 // indirect
	github.com/DataDog/go-libddwaf/v4 v4.8.0 // indirect
	github.com/DataDog/go-runtime-metrics-internal v0.0.4-0.20250721125240-fdf1ef85b633 // indirect
	github.com/DataDog/go-sqllexer v0.1.8 // indirect
	github.com/DeRuina/timberjack v1.3.9 // indirect
	github.com/KimMachineGun/automemlimit v0.7.5 // indirect
	github.com/Masterminds/goutils v1.1.1 // indirect
	github.com/Masterminds/semver/v3 v3.4.0 // indirect
	github.com/Masterminds/sprig/v3 v3.3.0 // indirect
	github.com/alecthomas/chroma/v2 v2.23.1 // indirect
	github.com/antlr4-go/antlr/v4 v4.13.1 // indirect
	github.com/aryann/difflib v0.0.0-20210328193216-ff5ff6dc229b // indirect
	github.com/aws/aws-sdk-go-v2 v1.41.1 // indirect
	github.com/aws/aws-sdk-go-v2/config v1.32.7 // indirect
	github.com/aws/aws-sdk-go-v2/credentials v1.19.7 // indirect
	github.com/aws/aws-sdk-go-v2/feature/ec2/imds v1.18.17 // indirect
	github.com/aws/aws-sdk-go-v2/internal/configsources v1.4.17 // indirect
	github.com/aws/aws-sdk-go-v2/internal/endpoints/v2 v2.7.17 // indirect
	github.com/aws/aws-sdk-go-v2/internal/ini v1.8.4 // indirect
	github.com/aws/aws-sdk-go-v2/service/internal/accept-encoding v1.13.4 // indirect
	github.com/aws/aws-sdk-go-v2/service/internal/presigned-url v1.13.17 // indirect
	github.com/aws/aws-sdk-go-v2/service/route53 v1.62.1 // indirect
	github.com/aws/aws-sdk-go-v2/service/secretsmanager v1.41.1 // indirect
	github.com/aws/aws-sdk-go-v2/service/signin v1.0.5 // indirect
	github.com/aws/aws-sdk-go-v2/service/sso v1.30.9 // indirect
	github.com/aws/aws-sdk-go-v2/service/ssooidc v1.35.13 // indirect
	github.com/aws/aws-sdk-go-v2/service/sts v1.41.6 // indirect
	github.com/aws/smithy-go v1.24.0 // indirect
	github.com/buger/jsonparser v1.1.1 // indirect
	github.com/caddyserver/certmagic v0.25.2 // indirect
	github.com/caddyserver/zerossl v0.1.5 // indirect
	github.com/ccoveille/go-safecast/v2 v2.0.0 // indirect
	github.com/cenkalti/backoff/v5 v5.0.3 // indirect
	github.com/cespare/xxhash v1.1.0 // indirect
	github.com/chenzhuoyu/iasm v0.9.0 // indirect
	github.com/chzyer/readline v1.5.1 // indirect
	github.com/cihub/seelog v0.0.0-20170130134532-f561c5e57575 // indirect
	github.com/cloudflare/circl v1.6.3 // indirect
	github.com/coreos/go-oidc/v3 v3.17.0 // indirect
	github.com/cpuguy83/go-md2man/v2 v2.0.7 // indirect
	github.com/dgraph-io/badger v1.6.2 // indirect
	github.com/dgraph-io/badger/v2 v2.2007.4 // indirect
	github.com/dgraph-io/ristretto v0.2.0 // indirect
	github.com/dgryski/go-farm v0.0.0-20240924180020-3414d57e47da // indirect
	github.com/dlclark/regexp2 v1.11.5 // indirect
	github.com/felixge/httpsnoop v1.0.4 // indirect
	github.com/fxamacker/cbor/v2 v2.9.0 // indirect
	github.com/go-jose/go-jose/v3 v3.0.4 // indirect
	github.com/go-jose/go-jose/v4 v4.1.4 // indirect
	github.com/go-logr/stdr v1.2.2 // indirect
	github.com/go-ole/go-ole v1.3.0 // indirect
	github.com/go-task/slim-sprig/v3 v3.0.0 // indirect
	github.com/gofrs/uuid v4.4.0+incompatible // indirect
	github.com/golang-jwt/jwt/v5 v5.3.0 // indirect
	github.com/google/cel-go v0.27.0 // indirect
	github.com/google/certificate-transparency-go v1.1.8-0.20240110162603-74a5dd331745 // indirect
	github.com/google/gnostic-models v0.7.0 // indirect
	github.com/google/go-tpm v0.9.8 // indirect
	github.com/google/go-tspi v0.3.0 // indirect
	github.com/grpc-ecosystem/grpc-gateway/v2 v2.28.0 // indirect
	github.com/hashicorp/go-version v1.7.0 // indirect
	github.com/huandu/xstrings v1.5.0 // indirect
	github.com/inconshreveable/mousetrap v1.1.0 // indirect
	github.com/jackc/pgpassfile v1.0.0 // indirect
	github.com/jackc/pgservicefile v0.0.0-20221227161230-091c0ba34f0a // indirect
	github.com/jackc/pgx/v5 v5.6.0 // indirect
	github.com/jackc/puddle/v2 v2.2.1 // indirect
	github.com/klauspost/compress v1.18.4 // indirect
	github.com/libdns/libdns v1.1.1 // indirect
	github.com/lufia/plan9stats v0.0.0-20250317134145-8bc96cf8fc35 // indirect
	github.com/manifoldco/promptui v0.9.0 // indirect
	github.com/mgutz/ansi v0.0.0-20200706080929-d51e80ef957d // indirect
	github.com/mholt/acmez/v3 v3.1.6 // indirect
	github.com/minio/simdjson-go v0.4.5 // indirect
	github.com/mitchellh/copystructure v1.2.0 // indirect
	github.com/mitchellh/go-ps v1.0.0 // indirect
	github.com/mitchellh/reflectwalk v1.0.2 // indirect
	github.com/oschwald/geoip2-golang/v2 v2.1.0 // indirect
	github.com/oschwald/maxminddb-golang/v2 v2.1.1 // indirect
	github.com/pbnjay/memory v0.0.0-20210728143218-7b4eea64cf58 // indirect
	github.com/pierrec/lz4/v4 v4.1.21 // indirect
	github.com/pires/go-proxyproto v0.11.0 // indirect
	github.com/planetscale/vtprotobuf v0.6.1-0.20240319094008-0393e58bdf10 // indirect
	github.com/pmezard/go-difflib v1.0.1-0.20181226105442-5d4384ee4fb2 // indirect
	github.com/power-devops/perfstat v0.0.0-20240221224432-82ca36839d55 // indirect
	github.com/prometheus/otlptranslator v1.0.0 // indirect
	github.com/puzpuzpuz/xsync/v3 v3.5.1 // indirect
	github.com/quic-go/qpack v0.6.0 // indirect
	github.com/rs/xid v1.6.0 // indirect
	github.com/russross/blackfriday/v2 v2.1.0 // indirect
	github.com/shirou/gopsutil/v4 v4.25.8-0.20250809033336-ffcdc2b7662f // indirect
	github.com/shopspring/decimal v1.4.0 // indirect
	github.com/shurcooL/sanitized_anchor_name v1.0.0 // indirect
	github.com/sirupsen/logrus v1.9.4 // indirect
	github.com/slackhq/nebula v1.10.3 // indirect
	github.com/smallstep/certificates v0.30.0-rc3 // indirect
	github.com/smallstep/cli-utils v0.12.2 // indirect
	github.com/smallstep/go-attestation v0.4.4-0.20241119153605-2306d5b464ca // indirect
	github.com/smallstep/linkedca v0.25.0 // indirect
	github.com/smallstep/pkcs7 v0.2.1 // indirect
	github.com/smallstep/scep v0.0.0-20250318231241-a25cabb69492 // indirect
	github.com/smallstep/truststore v0.13.0 // indirect
	github.com/spf13/cast v1.7.0 // indirect
	github.com/spf13/cobra v1.10.2 // indirect
	github.com/tailscale/go-winio v0.0.0-20231025203758-c4f33415bf55 // indirect
	github.com/tailscale/tscert v0.0.0-20251216020129-aea342f6d747 // indirect
	github.com/theckman/httpforwarded v0.4.0 // indirect
	github.com/tklauser/go-sysconf v0.3.15 // indirect
	github.com/tklauser/numcpus v0.10.0 // indirect
	github.com/urfave/cli v1.22.17 // indirect
	github.com/x448/float16 v0.8.4 // indirect
	github.com/yuin/goldmark v1.7.16 // indirect
	github.com/yuin/goldmark-highlighting/v2 v2.0.0-20230729083705-37449abec8cc // indirect
	github.com/yusufpapurcu/wmi v1.2.4 // indirect
	github.com/zeebo/blake3 v0.2.4 // indirect
	go.etcd.io/bbolt v1.3.10 // indirect
	go.opentelemetry.io/auto/sdk v1.2.1 // indirect
	go.opentelemetry.io/collector/component v1.39.0 // indirect
	go.opentelemetry.io/collector/featuregate v1.46.0 // indirect
	go.opentelemetry.io/collector/internal/telemetry v0.133.0 // indirect
	go.opentelemetry.io/collector/pdata v1.46.0 // indirect
	go.opentelemetry.io/collector/pdata/pprofile v0.140.0 // indirect
	go.opentelemetry.io/contrib/bridges/otelzap v0.12.0 // indirect
	go.opentelemetry.io/contrib/bridges/prometheus v0.65.0 // indirect
	go.opentelemetry.io/contrib/exporters/autoexport v0.65.0 // indirect
	go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.65.0 // indirect
	go.opentelemetry.io/contrib/propagators/autoprop v0.65.0 // indirect
	go.opentelemetry.io/contrib/propagators/aws v1.40.0 // indirect
	go.opentelemetry.io/contrib/propagators/b3 v1.40.0 // indirect
	go.opentelemetry.io/contrib/propagators/jaeger v1.40.0 // indirect
	go.opentelemetry.io/contrib/propagators/ot v1.40.0 // indirect
	go.opentelemetry.io/otel v1.43.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc v0.16.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploghttp v0.19.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc v1.40.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp v1.40.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlptrace v1.43.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc v1.40.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp v1.43.0 // indirect
	go.opentelemetry.io/otel/exporters/prometheus v0.62.0 // indirect
	go.opentelemetry.io/otel/exporters/stdout/stdoutlog v0.16.0 // indirect
	go.opentelemetry.io/otel/exporters/stdout/stdoutmetric v1.40.0 // indirect
	go.opentelemetry.io/otel/exporters/stdout/stdouttrace v1.40.0 // indirect
	go.opentelemetry.io/otel/log v0.19.0 // indirect
	go.opentelemetry.io/otel/metric v1.43.0 // indirect
	go.opentelemetry.io/otel/sdk v1.43.0 // indirect
	go.opentelemetry.io/otel/sdk/log v0.19.0 // indirect
	go.opentelemetry.io/otel/sdk/metric v1.43.0 // indirect
	go.opentelemetry.io/otel/trace v1.43.0 // indirect
	go.opentelemetry.io/proto/otlp v1.10.0 // indirect
	go.step.sm/crypto v0.76.2 // indirect
	go.uber.org/automaxprocs v1.6.0 // indirect
	go.uber.org/multierr v1.11.0 // indirect
	go.uber.org/zap/exp v0.3.0 // indirect
	go.yaml.in/yaml/v2 v2.4.3 // indirect
	go.yaml.in/yaml/v3 v3.0.4 // indirect
	golang.org/x/crypto/x509roots/fallback v0.0.0-20260213171211-a408498e5541 // indirect
	google.golang.org/genproto/googleapis/api v0.0.0-20260401024825-9d38bb4040a9 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20260401024825-9d38bb4040a9 // indirect
	google.golang.org/grpc/cmd/protoc-gen-go-grpc v1.5.1 // indirect
	gopkg.in/evanphx/json-patch.v4 v4.12.0 // indirect
	gopkg.in/ini.v1 v1.67.0 // indirect
	howett.net/plist v1.0.0 // indirect
	sigs.k8s.io/mcs-api v0.3.0 // indirect
	sigs.k8s.io/randfill v1.0.0 // indirect
	sigs.k8s.io/structured-merge-diff/v6 v6.3.0 // indirect
)

replace layeh.com/radius => github.com/inverse-inc/go-radius v0.0.0-20221114145510-67bfba021ae4

replace github.com/inverse-inc/packetfence => ../

replace github.com/inverse-inc/packetfence/go => ./
