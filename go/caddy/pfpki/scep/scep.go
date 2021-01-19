package scep

import (
	"net/http"
	"os"

	"github.com/fdurand/scep/csrverifier"
	"github.com/fdurand/scep/csrverifier/executable"
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

	var csrVerifier csrverifier.CSRVerifier

	var err error

	executableCSRVerifier, err := executablecsrverifier.New("/tmp/x.sh", lginfo)
	if err != nil {
		lginfo.Log("err", err, "msg", "Could not instantiate CSR verifier")
		os.Exit(1)
	}
	csrVerifier = executableCSRVerifier

	log.LoggerWContext(*pfpki.Ctx).Info("SCEP GET From ", r.Method, " To: ", r.URL.String())

	o := models.NewCAModel(pfpki)
	profileName := vars["id"]
	profile, err := o.FindSCEPProfile([]string{profileName})
	var svc scepserver.Service // scep service
	{
		svcOptions := []scepserver.ServiceOption{
			scepserver.Profile(vars["id"]),
			scepserver.ClientValidity(profile[0].Validity),
			scepserver.WithCSRVerifier(csrVerifier),
			// Number of days before allow renewal
			scepserver.AllowRenewal(14),
			scepserver.ChallengePassword("bob"),
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
