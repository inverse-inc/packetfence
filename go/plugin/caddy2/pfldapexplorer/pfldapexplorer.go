package pfldapexplorer

import (
	"context"
	"encoding/json"
	"io/ioutil"
	"net/http"
	"time"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/go-chi/chi/v5"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/api-frontend/unifiedapierrors"
	"github.com/inverse-inc/packetfence/go/common/ldapClient"
	"github.com/inverse-inc/packetfence/go/common/ldapSearchClient"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
)

var ApiPrefix = "/api/v1"
var LdapSearchEndpoint = "/ldap/search"

// Connection timeout needs to be low, because this explorer is used to fill the dropdowns in the admin UI
// Setting this higher means that all IP addresses of the server that do not respond will cause a time delay in the UI
var serverConnectionTimeout = time.Second

type Handler struct {
	Router     *chi.Mux
	Ctx        context.Context
	connectors *connector.ConnectorsContainer
}

type SearchRequest struct {
	Server      ldapSearchClient.LdapServer  `json:"server"`
	SearchQuery ldapSearchClient.SearchQuery `json:"search_query"`
}

func init() {
	caddy.RegisterModule(Handler{})
	httpcaddyfile.RegisterHandlerDirective("pfldapexplorer", utils.ParseCaddyfile[Handler])
}

// CaddyModule returns the Caddy module information.
func (Handler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.pfldapexplorer",
		New: func() caddy.Module {
			return &Handler{}
		},
	}
}

func (m *Handler) Provision(_ caddy.Context) error {
	ctx := log.LoggerNewContext(context.Background())

	err := m.buildPfldapExplorer(ctx)
	if err != nil {
		return nil
	}

	return nil
}

func (h *Handler) buildPfldapExplorer(ctx context.Context) error {

	h.Ctx = ctx
	h.connectors = connector.NewConnectorsContainer(ctx)

	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	h.Router = chi.NewRouter()
	ldapSearchUrl := ApiPrefix + LdapSearchEndpoint

	h.Router.Post(ldapSearchUrl, h.HandleLDAPSearchRequest)

	return nil

}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	ctx := r.Context()
	defer panichandler.Http(ctx, w)
	chiCtx := chi.NewRouteContext()
	ctx = context.WithValue(ctx, chi.RouteCtxKey, chiCtx)
	r = r.WithContext(ctx)

	if h.Router.Match(chiCtx, r.Method, r.URL.Path) {
		h.Router.ServeHTTP(w, r)

		// TODO change me and wrap actions into something that handles server errors
		return nil
	}

	return next.ServeHTTP(w, r)
}

func (h *Handler) HandleLDAPSearchRequest(res http.ResponseWriter, req *http.Request) {

	defer func() {
		if err := recover(); err != nil {
			unifiedapierrors.Error(res, "Error parsing incomming request", http.StatusBadRequest)
		}
	}()

	var searchRequest = SearchRequest{}
	body, err := ioutil.ReadAll(req.Body)
	if err != nil {
		log.LoggerWContext(h.Ctx).Info(err.Error())
		unifiedapierrors.Error(res, err.Error(), http.StatusBadRequest)
		return
	}

	if err = json.Unmarshal(body, &searchRequest); err != nil {
		log.LoggerWContext(h.Ctx).Info(err.Error())
		unifiedapierrors.Error(res, err.Error(), http.StatusBadRequest)
		return
	}

	var factory ldapClient.ILdapClientFactory
	if searchRequest.Server.UseConnector {
		factory = ldapClient.ProxyLdapClientFactory{ConnectorContext: connector.WithConnectorsContainer(req.Context(), h.connectors)}
	} else {
		factory = ldapClient.LdapClientFactory{}
	}
	ldapSearchClient := ldapSearchClient.LdapSearchClient{
		LdapServer:        &searchRequest.Server,
		Timeout:           serverConnectionTimeout,
		LdapClientFactory: factory,
	}
	results, err := ldapSearchClient.SearchLdap(&searchRequest.SearchQuery)
	if err != nil {
		log.LoggerWContext(h.Ctx).Info(err.Error())
		unifiedapierrors.Error(res, err.Error(), http.StatusBadRequest)
		return
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(results); err != nil {
		panic(err)
	}
}

func (h *Handler) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	c.Next()
	return nil
}
