package pfldapexplorer

import (
	"context"
	"encoding/json"
	"io/ioutil"
	"net/http"
	"time"

	"github.com/go-chi/chi"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/api-frontend/unifiedapierrors"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/common/ldapClient"
	"github.com/inverse-inc/packetfence/go/common/ldapSearchClient"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/panichandler"
)

var ApiPrefix = "/api/v1"
var LdapSearchEndpoint = "/ldap/search"

// Connection timeout needs to be low, because this explorer is used to fill the dropdowns in the admin UI
// Setting this higher means that all IP addresses of the server that do not respond will cause a time delay in the UI
var serverConnectionTimeout = time.Second

type Handler struct {
	Next       httpserver.Handler
	Router     *chi.Mux
	Ctx        *context.Context
	connectors *connector.ConnectorsContainer
}

type SearchRequest struct {
	Server      ldapSearchClient.LdapServer  `json:"server"`
	SearchQuery ldapSearchClient.SearchQuery `json:"search_query"`
}

func init() {
	caddy.RegisterPlugin("pfldapexplorer", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

func setup(c *caddy.Controller) error {
	ctx := log.LoggerNewContext(context.Background())

	pfldapexplorer, err := buildPfldapExplorer(ctx)
	sharedutils.CheckError(err)

	pfldapexplorer.connectors = connector.NewConnectorsContainer(ctx)

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		pfldapexplorer.Next = next
		return pfldapexplorer
	})

	return nil
}

func buildPfldapExplorer(ctx context.Context) (Handler, error) {

	pfldapexplorer := Handler{}

	pfldapexplorer.Ctx = &ctx
	pfldapexplorer.connectors = connector.NewConnectorsContainer(ctx)

	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	pfldapexplorer.Router = chi.NewRouter()
	ldapSearchUrl := ApiPrefix + LdapSearchEndpoint

	pfldapexplorer.Router.Post(ldapSearchUrl, pfldapexplorer.HandleLDAPSearchRequest)

	return pfldapexplorer, nil

}

func (h Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()
	defer panichandler.Http(ctx, w)
	chiCtx := chi.NewRouteContext()
	ctx = context.WithValue(ctx, chi.RouteCtxKey, chiCtx)
	r = r.WithContext(ctx)

	if h.Router.Match(chiCtx, r.Method, r.URL.Path) {
		h.Router.ServeHTTP(w, r)

		// TODO change me and wrap actions into something that handles server errors
		return 0, nil
	}
	return h.Next.ServeHTTP(w, r)
}

func (h *Handler) HandleLDAPSearchRequest(res http.ResponseWriter, req *http.Request) {
	var searchRequest = SearchRequest{}
	body, err := ioutil.ReadAll(req.Body)
	if err != nil {
		log.LoggerWContext(*h.Ctx).Info(err.Error())
		unifiedapierrors.Error(res, err.Error(), http.StatusBadRequest)
		return
	}

	if err = json.Unmarshal(body, &searchRequest); err != nil {
		log.LoggerWContext(*h.Ctx).Info(err.Error())
		unifiedapierrors.Error(res, err.Error(), http.StatusBadRequest)
		return
	}

	searchRequest.SearchQuery.Context = connector.WithConnectorsContainer(req.Context(), h.connectors)

	var factory ldapClient.ILdapClientFactory
	if searchRequest.Server.UseConnector {
		factory = ldapClient.ProxyLdapClientFactory{}
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
		log.LoggerWContext(*h.Ctx).Info(err.Error())
		unifiedapierrors.Error(res, err.Error(), http.StatusBadRequest)
		return
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(results); err != nil {
		panic(err)
	}
}
