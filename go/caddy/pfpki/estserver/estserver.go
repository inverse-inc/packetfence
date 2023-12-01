package estserver

import (
	"net/http"

	"github.com/fdurand/est"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/models"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/types"
)

func EstHandler(pfpki *types.Handler, w http.ResponseWriter, r *http.Request) {
	vars := types.Params(r, "id")

	o := models.NewCAModel(pfpki)
	profileName := vars["id"]

	profile, err := o.GetESTProfile(profileName)
	if err != nil {
		log.LoggerWContext(*pfpki.Ctx).Info("Unable to find the profile")
	}

	// config := &est.ServerConfig{}
	// config.CA = profile.Ca

	esthandler, err := est.NewRouter(&est.ServerConfig{
		CA: profile.Ca,
		// Logger: log.LoggerWContext(*pfpki.Ctx),
		// AllowedHosts:   cfg.AllowedHosts,
		// Timeout:        time.Duration(cfg.Timeout) * time.Second,
		// RateLimit:      cfg.RateLimit,
		// CheckBasicAuth: pwfunc,
	})
	esthandler.ServeHTTP(w, r)
	log.LoggerWContext(*pfpki.Ctx).Info("EST " + r.Method + " To: " + r.URL.String())
}
