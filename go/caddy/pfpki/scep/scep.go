package scep

import (
	"net/http"
	"os"

	scepserver "github.com/fdurand/scep/server"
	kitlog "github.com/go-kit/kit/log"
	kitloglevel "github.com/go-kit/kit/log/level"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/models"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/types"
	"github.com/inverse-inc/packetfence/go/log"
)

func ScepHandler(pfpki *types.Handler, w http.ResponseWriter, r *http.Request) {

	var logger kitlog.Logger
	{

		logger = kitlog.NewLogfmtLogger(os.Stderr)
		logger = kitloglevel.NewFilter(logger, kitloglevel.AllowInfo())
		logger = kitlog.With(logger, "ts", kitlog.DefaultTimestampUTC)
		logger = kitlog.With(logger, "caller", kitlog.DefaultCaller)
	}
	lginfo := kitloglevel.Info(logger)

	log.LoggerWContext(*pfpki.Ctx).Info("SCEP GET From ", r.Method, " To: ", r.URL.String())

	var err error

	o := models.NewCAModel(pfpki)

	var svc scepserver.Service // scep service
	{
		svcOptions := []scepserver.ServiceOption{
			scepserver.ChallengePassword(""),
			// scepserver.WithCSRVerifier(csrVerifier),
			scepserver.CAKeyPassword([]byte("")),
			scepserver.ClientValidity(365),
			scepserver.AllowRenewal(0),
			// scepserver.WithLogger(logger),
		}
		svc, err = scepserver.NewService(o, svcOptions...)
		if err != nil {
			log.LoggerWContext(*pfpki.Ctx).Info("err ", err)
		}
		svc = scepserver.NewLoggingService(kitlog.With(lginfo, "component", "scep_service"), svc)
	}

	var h http.Handler // http handler
	{
		e := scepserver.MakeServerEndpoints(svc)
		e.GetEndpoint = scepserver.EndpointLoggingMiddleware(lginfo)(e.GetEndpoint)
		e.PostEndpoint = scepserver.EndpointLoggingMiddleware(lginfo)(e.PostEndpoint)
		h = scepserver.MakeHTTPHandler(e, svc, kitlog.With(lginfo, "component", "http"))
	}

	h.ServeHTTP(w, r)

}
