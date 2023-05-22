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
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"gopkg.in/ldap.v2"
	"k8s.io/utils/strings/slices"
)

var ApiPrefix = "/api/v1"
var LdapSearchEndpoint = "/ldap/search"

// Connection timeout needs to be low, because this explorer is used to fill the dropdowns in the admin UI
// Setting this higher means that all IP addresses of the server that do not respond will cause a time delay in the UI
var serverConnectionTimeout = time.Second

type LdapServer struct {
	pfconfigdriver.AuthenticationSourceLdap
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

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		pfldapexplorer.Next = next
		return pfldapexplorer
	})

	return nil
}

func buildPfldapExplorer(ctx context.Context) (Handler, error) {

	pfldapexplorer := Handler{}

	pfldapexplorer.Ctx = &ctx

	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	pfldapexplorer.Router = chi.NewRouter()
	ldapSearchUrl := ApiPrefix + LdapSearchEndpoint

	pfldapexplorer.Router.Post(ldapSearchUrl, pfldapexplorer.HandleLDAPSearchRequest)

	return pfldapexplorer, nil

}

type Handler struct {
	Next   httpserver.Handler
	Router *chi.Mux
	Ctx    *context.Context
}

var (
	scopes = map[string]int{
		"base": ldap.ScopeBaseObject,
		"one":  ldap.ScopeSingleLevel,
		"sub":  ldap.ScopeWholeSubtree,
	}
)

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

func getLdapServerFromConfig(ctx context.Context, serverId string) *LdapServer {
	var sections pfconfigdriver.PfconfigKeys
	sections.PfconfigNS = "resource::authentication_sources_ldap"

	pfconfigdriver.FetchDecodeSocket(ctx, &sections)
	if slices.Contains(sections.Keys, serverId) {
		var server LdapServer
		server.PfconfigNS = sections.PfconfigNS
		server.PfconfigHashNS = serverId
		pfconfigdriver.FetchDecodeSocket(ctx, &server)
		return &server
	} else {
		return nil
	}
}

func (h *Handler) HandleLDAPSearchRequest(res http.ResponseWriter, req *http.Request) {
	var searchQuery = SearchQuery{}
	body, err := ioutil.ReadAll(req.Body)
	if err != nil {
		log.LoggerWContext(*h.Ctx).Info(err.Error())
	}

	if err = json.Unmarshal(body, &searchQuery); err != nil {
		log.LoggerWContext(*h.Ctx).Info(err.Error())
	}

	ldapSearchServer := getLdapServerFromConfig(req.Context(), searchQuery.Server)
	ldapSearchClient := LdapSearchClient{LdapServer: ldapSearchServer, Timeout: serverConnectionTimeout, LdapClientFactory: LdapClientFactory{}}
	results, err := ldapSearchClient.SearchLdap(&searchQuery)
	if err != nil {
		log.LoggerWContext(*h.Ctx).Info(err.Error())
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(results); err != nil {
		panic(err)
	}
}
