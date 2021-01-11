package scep

import (
	"net/http"
	"os"

	scepserver "github.com/fdurand/scep/server"
	kitlog "github.com/go-kit/kit/log"
	kitloglevel "github.com/go-kit/kit/log/level"
	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/models"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/types"
	"github.com/inverse-inc/packetfence/go/log"
)

func ScepHandler(pfpki *types.Handler, w http.ResponseWriter, r *http.Request) {

	vars := mux.Vars(r)

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
	profileName := vars["id"]
	profile, err := o.FindSCEPProfile([]string{profileName})
	var svc scepserver.Service // scep service
	{
		svcOptions := []scepserver.ServiceOption{
			scepserver.Profile(vars["id"]),
			scepserver.ClientValidity(profile[0].Validity),
			// Number of days before allow renewal
			scepserver.AllowRenewal(14),
		}
		svc, err = scepserver.NewService(o, svcOptions...)
		if err != nil {
			log.LoggerWContext(*pfpki.Ctx).Info("err ", err)
			panic("Unable to create new service: " + err.Error())
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
