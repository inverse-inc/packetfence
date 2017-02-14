package pfsso

import (
	"fmt"
	"github.com/fingerbank/processor/log"
	"github.com/fingerbank/processor/statsd"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/julienschmidt/httprouter"
	"io"
	"net/http"
	"runtime/debug"
)

func init() {
	caddy.RegisterPlugin("pfsso", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

func (h PfssoHandler) handlePing(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	defer statsd.NewStatsDTiming(ctx).Send("PfssoHandler.handlePing")
	io.WriteString(w, "pong")
}

func setup(c *caddy.Controller) error {

	pfsso := PfssoHandler{}
	router := httprouter.New()
	router.GET("/ping", pfsso.handlePing)
	//router.POST("/pfsso/start", pfsso.handleStart)
	//router.POST("/pfsso/stop", pfsso.handleStop)

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		pfsso.Next = next
		pfsso.router = router
		return pfsso
	})

	return nil
}

type PfssoHandler struct {
	Next   httpserver.Handler
	router *httprouter.Router
}

func (h PfssoHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()

	defer func() {
		if r := recover(); r != nil {
			msg := fmt.Sprintf("Recovered panic: %s.", r)
			log.LoggerWContext(ctx).Error(msg)
			fmt.Println(msg)
			debug.PrintStack()
			http.Error(w, "An internal error has occured, please check server side logs for details.", http.StatusInternalServerError)
		}
	}()

	if handle, params, _ := h.router.Lookup(r.Method, r.URL.Path); handle != nil {
		handle(w, r, params)
		// TODO change me and wrap actions into something that handles server errors
		return 0, nil
	} else {
		return h.Next.ServeHTTP(w, r)
	}
}
