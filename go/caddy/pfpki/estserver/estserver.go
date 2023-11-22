package estserver

import (
	"net/http"

	"github.com/globalsign/est"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/models"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/types"
)

func EstHandler(pfpki *types.Handler, w http.ResponseWriter, r *http.Request) {
	vars := types.Params(r, "id")

	o := models.NewCAModel(pfpki)
	profileName := vars["id"]

	profile, err := o.GetProfile(profileName)
	if err != nil {
		log.LoggerWContext(*pfpki.Ctx).Info("Unable to find the profile")
	}
	// o.CAbyProfile(nil, profile[0].Name)
	config := &est.ServerConfig{}
	config.CA = profile.Ca
	log.LoggerWContext(*pfpki.Ctx).Info("EST " + r.Method + " To: " + r.URL.String())
}
