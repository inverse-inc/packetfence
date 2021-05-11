package scep

import (
	"net/http"
	"os"

	"github.com/fdurand/scep/csrverifier"
	scepdepot "github.com/fdurand/scep/depot"
	scepserver "github.com/fdurand/scep/server"
	kitlog "github.com/go-kit/kit/log"
	kitloglevel "github.com/go-kit/kit/log/level"
	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/cloud"
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

	var err error

	log.LoggerWContext(*pfpki.Ctx).Info("SCEP GET From " + r.Method + " To: " + r.URL.String())

	o := models.NewCAModel(pfpki)
	profileName := vars["id"]
	profile, err := o.FindSCEPProfile([]string{profileName})

	if err != nil {
		log.LoggerWContext(*pfpki.Ctx).Info("Unable to find the profile")
	}

	var svc scepserver.Service // scep service
	{
		crts, key, err := o.CA(nil)
		if err != nil {
			lginfo.Log("err", err)
			os.Exit(1)
		}
		if len(crts) < 1 {
			lginfo.Log("err", "missing CA certificate")
			os.Exit(1)
		}

		prof, _ := o.FindSCEPProfile([]string{vars["id"]})
		var vcloud cloud.Cloud
		if prof[0].CloudEnabled == 1 {
			vcloud, err = cloud.Create(*pfpki.Ctx, "intune", prof[0].CloudService)
			o.Cloud = vcloud
			if err != nil {
				lginfo.Log("err", "Enable to create CLoud service")
				os.Exit(1)
			}
		}
		var signer scepserver.CSRSigner = scepdepot.NewSigner(
			o,
			scepdepot.WithAllowRenewalDays(profile[0].SCEPDaysBeforeRenewal),
			scepdepot.WithValidityDays(profile[0].Validity),
			scepdepot.WithProfile(vars["id"]),
			scepdepot.WithAttributes(ProfileAttributes(profile[0])),
			// Todo Support CA password
			// scepdepot.WithCAPass(*flCAPass),
		)
		if prof[0].CloudEnabled != 1 {
			signer = scepserver.ChallengeMiddleware(profile[0].SCEPChallengePassword, signer)
		}
		// Load the Intune/MDM csr Verifier
		signer = csrverifier.Middleware(o, signer)

		svc, err = scepserver.NewService(crts[0], key, signer, scepserver.WithLogger(logger))
		if err != nil {
			lginfo.Log("err", err)
			os.Exit(1)
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

func ProfileAttributes(prof models.Profile) map[string]string {
	var attributes map[string]string
	attributes = make(map[string]string)

	if len(prof.Organisation) > 0 {
		attributes["Organization"] = prof.Organisation
	}

	if len(prof.OrganisationalUnit) > 0 {
		attributes["OrganizationalUnit"] = prof.OrganisationalUnit
	}

	if len(prof.Country) > 0 {
		attributes["Country"] = prof.Country
	}

	if len(prof.State) > 0 {
		attributes["State"] = prof.State
	}

	if len(prof.Locality) > 0 {
		attributes["Locality"] = prof.Locality
	}

	if len(prof.StreetAddress) > 0 {
		attributes["StreetAddress"] = prof.StreetAddress
	}

	if len(prof.PostalCode) > 0 {
		attributes["PostalCode"] = prof.PostalCode
	}

	if len(*prof.ExtendedKeyUsage) > 0 {
		attributes["ExtendedKeyUsage"] = *prof.ExtendedKeyUsage
	}
	if len(*prof.KeyUsage) > 0 {
		attributes["KeyUsage"] = *prof.KeyUsage
	}

	if len(prof.OCSPUrl) > 0 {
		attributes["OCSPUrl"] = prof.OCSPUrl
	}

	if len(prof.Mail) > 0 {
		attributes["Mail"] = prof.Mail
	}

	return attributes
}
