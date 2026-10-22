package cos

import (
	"log"
	"net/http"
	_ "net/http/pprof" //import http profiler api
	"os"
	"strings"
)

//pprofEnv is the environment variable used to enable the net/http/pprof
//profiling server at runtime.
const pprofEnv = "CHISEL_PPROF"

//defaultPprofAddr is used when CHISEL_PPROF is set to a plain truthy value
//rather than an explicit listen address.
const defaultPprofAddr = "localhost:6060"

//pprofAddr resolves the CHISEL_PPROF environment variable into a listen
//address. It returns ("", false) when profiling should stay disabled.
//  unset / "" / "0" / "false" / "no" / "off" -> disabled
//  "1" / "true" / "yes" / "on"               -> localhost:6060
//  "host:port"                               -> that address (lets client
//                                              and server avoid colliding
//                                              on the same port)
func pprofAddr() (string, bool) {
	v := strings.TrimSpace(os.Getenv(pprofEnv))
	switch strings.ToLower(v) {
	case "", "0", "false", "no", "off":
		return "", false
	case "1", "true", "yes", "on":
		return defaultPprofAddr, true
	default:
		return v, true
	}
}

func init() {
	addr, enabled := pprofAddr()
	if !enabled {
		return
	}
	go func() {
		log.Printf("[pprof] listening on %s", addr)
		if err := http.ListenAndServe(addr, nil); err != nil {
			log.Printf("[pprof] listener on %s stopped: %s", addr, err)
		}
	}()
}
