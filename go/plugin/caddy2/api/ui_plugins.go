package api

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/uiplugins"
	"github.com/julienschmidt/httprouter"
)

var uiPluginsFetcher = uiplugins.NewFetcher(func(ctx context.Context, msg string) {
	log.LoggerWContext(ctx).Warn(msg)
})

// loads the registrations, a variable for the tests
var uiPluginsRegistrations = uiplugins.LoadRegistrations

// GET /api/v1/ui_plugins: the admin UI plugins registered in redis (through the
// resource::ui_plugins pfconfig namespace) whose manifest is reachable and
// valid. See docs/ui-plugins/README.md.
func (h APIHandler) uiPlugins(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	plugins := []uiplugins.Plugin{}
	registrations, err := uiPluginsRegistrations(ctx)
	if err != nil {
		// the admin UI must work without any plugin
		log.LoggerWContext(ctx).Error("Unable to load the UI plugins registrations: " + err.Error())
	} else {
		plugins = uiPluginsFetcher.Plugins(ctx, registrations)
	}
	json.NewEncoder(w).Encode(struct {
		Items  []uiplugins.Plugin `json:"items"`
		Status int                `json:"status"`
	}{Items: plugins, Status: http.StatusOK})
}
