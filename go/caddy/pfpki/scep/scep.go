package scep

import (
	"context"
	"net/http"

	scepserver "github.com/fdurand/scep/server"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/models"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/types"
	"github.com/inverse-inc/packetfence/go/log"
)

func ScepHandler(pfpki *types.Handler, w http.ResponseWriter, r *http.Request) {

	svcOptions := []scepserver.ServiceOption{
		scepserver.ChallengePassword(""),
		//scepserver.WithCSRVerifier(csrVerifier),
		scepserver.CAKeyPassword([]byte("")),
		scepserver.ClientValidity(365),
		scepserver.AllowRenewal(0),
		//scepserver.WithLogger(logger),
	}

	log.LoggerWContext(*pfpki.Ctx).Info("SCEP GET From ", r.Method, " To: ", r.URL.String())

	operation := r.URL.Query().Get("operation")
	message := r.URL.Query().Get("message")

	switch operation {
	// case "GetCACaps":
	// 	o := models.NewCAModel(pfpki)
	// 	svc, err := scepserver.NewService(o, svcOptions...)
	// 	res, err := svc.GetCACaps(context.Background())
	// 	if err != nil {
	// 		panic(err)
	// 	}
	// 	w.Write(res)
	case "GetCACert":
		o := models.NewCAModel(pfpki)
		if message != "" {
			o.Cn = message
		}
		svc, err := scepserver.NewService(o, svcOptions...)

		if err != nil {
			panic(err)
		}
		res, _, err := svc.GetCACert(context.Background())
		if err != nil {
			panic(err)
		}
		w.Header().Set("Content-Type", "application/x-x509-ca-cert")
		w.Write(res)
	// case "PKIOperation":
	// 	body, err := ioutil.ReadAll(r.Body)
	// 	if err != nil {
	// 		panic(err)
	// 	}
	// 	res, err := svc.PKIOperation(context.Background(), body)
	// 	if err != nil {
	// 		panic(err)
	// 	}
	// 	w.Write(res)
	// case "GetNextCACert":
	// 	res, err := svc.GetNextCACert(context.Background())
	// 	if err != nil {
	// 		panic(err)
	// 	}
	// 	w.Write(res)
	default:
		http.Error(w, "Invalid Operation", 500)
	}
}
