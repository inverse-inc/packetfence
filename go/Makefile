include ../config.mk
GO ?= go
CGO_ENABLED=1
# to change the arch a binary is compiled for.
GOARCH=
build_cmd = CGO_ENABLED=$(CGO_ENABLED) $(if $(GOARCH),GOARCH=$(GOARCH),) $(GO) build $(ARGS)

# Pin analyzers independently of the application's module dependencies.
STATICCHECK_VERSION = v0.8.1
GOVULNCHECK_VERSION = v1.8.0
GOSEC_VERSION = v2.28.0
# Check the whole module on the build host, including packages requiring cgo.
