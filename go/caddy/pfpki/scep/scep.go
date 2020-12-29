package scep

import (
	"context"
	"io/ioutil"
	"net/http"

	"github.com/fdurand/scep/depot/file"
	scepserver "github.com/fdurand/scep/server"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/types"
	"github.com/inverse-inc/packetfence/go/log"
)

func ScepHandler(pfpki *types.Handler, w http.ResponseWriter, r *http.Request) {

	// Depot needs to fetch the db

	depot, err := file.NewFileDepot("depoty")
	if err != nil {
		panic(err)
	}

	svcOptions := []scepserver.ServiceOption{
		scepserver.ChallengePassword("secret"),
		//scepserver.WithCSRVerifier(csrVerifier),
		scepserver.CAKeyPassword([]byte("")),
		scepserver.ClientValidity(365),
		scepserver.AllowRenewal(0),
		//scepserver.WithLogger(logger),
	}

	svc, err := scepserver.NewService(depot, svcOptions...)
	if err != nil {
		panic(err)
	}
	log.LoggerWContext(pfpki.Ctx).Info("SCEP GET From ", r.Method, " To: ", r.URL.String())

	operation := r.URL.Query().Get("operation")

	switch operation {
	case "GetCACaps":
		res, err := svc.GetCACaps(context.Background())
		if err != nil {
			panic(err)
		}
		w.Write(res)
	case "GetCACert":
		res, _, err := svc.GetCACert(context.Background())
		if err != nil {
			panic(err)
		}
		w.Header().Set("Content-Type", "application/x-x509-ca-cert")
		w.Write(res)
	case "PKIOperation":
		body, err := ioutil.ReadAll(r.Body)
		if err != nil {
			panic(err)
		}
		res, err := svc.PKIOperation(context.Background(), body)
		if err != nil {
			panic(err)
		}
		w.Write(res)
	case "GetNextCACert":
		res, err := svc.GetNextCACert(context.Background())
		if err != nil {
			panic(err)
		}
		w.Write(res)
	default:
		http.Error(w, "Invalid Operation", 500)
	}
}
