package scep

import (
	"net/http"
	"os"

	kitlog "github.com/go-kit/log"
	kitloglevel "github.com/go-kit/log/level"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/cloud"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"github.com/inverse-inc/scep/csrverifier"
	scepdepot "github.com/inverse-inc/scep/depot"
	scepserver "github.com/inverse-inc/scep/server"
)

func ScepHandler(pfpki *types.Handler, w http.ResponseWriter, r *http.Request) {

	vars := types.Params(r, "id")

	var logger kitlog.Logger
	{

		logger = kitlog.NewLogfmtLogger(os.Stderr)
		logger = kitloglevel.NewFilter(logger, kitloglevel.AllowInfo())
		logger = kitlog.With(logger, "ts", kitlog.DefaultTimestampUTC)
		logger = kitlog.With(logger, "caller", kitlog.DefaultCaller)
	}
	lginfo := kitloglevel.Info(logger)

	var err error

	log.LoggerWContext(*pfpki.Ctx).Info("SCEP " + r.Method + " To: " + r.URL.String())

	o := models.NewCAModel(pfpki)
	profileName := vars["id"]
	profile, err := o.FindSCEPProfile([]string{profileName})

	if err != nil {
		log.LoggerWContext(*pfpki.Ctx).Info("Unable to find the profile")
	}

	var svc scepserver.Service // scep service

	{
		var signer scepserver.CSRSigner
		crts, key, err := o.CA(nil, profileName)
		if err != nil {
			lginfo.Log("err", err)
			return
		}
		if len(crts) < 1 {
			lginfo.Log("err", "missing CA certificate")
			return
		}
		var vcloud cloud.Cloud
		if profile[0].CloudEnabled == 1 {
			vcloud, err = cloud.Create(*pfpki.Ctx, "intune", profile[0].CloudService)
			o.Cloud = vcloud
			if err != nil {
				lginfo.Log("err", "Enable to create Cloud service")
				lginfo.Log("err", err.Error())
				return
			}
		}
		signer = scepdepot.NewSigner(
			o,
			scepdepot.WithAllowRenewalDays(profile[0].SCEPDaysBeforeRenewal),
			scepdepot.WithValidityDays(profile[0].Validity),
			scepdepot.WithProfile(vars["id"]),
			scepdepot.WithAttributes(models.ProfileAttributes(profile[0])),
			// Todo Support CA password
			// scepdepot.WithCAPass(*flCAPass),
		)
		if profile[0].CloudEnabled != 1 {
			signer = scepserver.ChallengeMiddleware(profile[0].SCEPChallengePassword, signer)
		}
		// Load the Intune/MDM csr Verifier
		signer = csrverifier.Middleware(o, signer)

		if profile[0].ScepServerEnabled == 1 {
			svc, err = scepserver.Create("proxy", crts[0], key, signer, scepserver.WithLogger(logger))
			svc.WithAddProxy(*pfpki.Ctx, profile[0].ScepServer.URL)
		} else {
			svc, err = scepserver.Create("server", crts[0], key, signer, scepserver.WithLogger(logger))
		}
		if err != nil {
			lginfo.Log("err", err)
			return
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
