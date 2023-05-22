package pfldapexplorer

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
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

type ldapServer struct {
	pfconfigdriver.AuthenticationSourceLdap
}

func init() {
	caddy.RegisterPlugin("pfldapexplorer", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

// Setup the pfldapexplorer middleware
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

// Handler struct
type Handler struct {
	Next   httpserver.Handler
	Router *chi.Mux
	Ctx    *context.Context
}

type Search struct {
	Server     string   `json:"server"`
	Search     string   `json:"search"`
	Attributes []string `json:"attributes,omitempty"`
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

func getLdapServerFromConfig(ctx context.Context, serverId string) *ldapServer {
	var sections pfconfigdriver.PfconfigKeys
	sections.PfconfigNS = "resource::authentication_sources_ldap"

	pfconfigdriver.FetchDecodeSocket(ctx, &sections)
	if slices.Contains(sections.Keys, serverId) {
		var server ldapServer
		server.PfconfigNS = sections.PfconfigNS
		server.PfconfigHashNS = serverId
		pfconfigdriver.FetchDecodeSocket(ctx, &server)
		return &server
	} else {
		return nil
	}
}

func (h *Handler) HandleLDAPSearchRequest(res http.ResponseWriter, req *http.Request) {
	var LdapSearch = Search{}
	body, err := ioutil.ReadAll(req.Body)
	if err != nil {
		log.LoggerWContext(*h.Ctx).Info(err.Error())
	}

	if err = json.Unmarshal(body, &LdapSearch); err != nil {
		log.LoggerWContext(*h.Ctx).Info(err.Error())
	}
	h.search(&LdapSearch, res, req)
}

func (h *Handler) search(ldapInfo *Search, res http.ResponseWriter, req *http.Request) {
	ldapSearchServer := getLdapServerFromConfig(req.Context(), ldapInfo.Server)
	fmt.Println(ldapSearchServer)

	conn, err := h.connect(ldapSearchServer)

	defer conn.Close()

	if err != nil {
		log.LoggerWContext(*h.Ctx).Error("Error connecting to LDAP source: " + err.Error())
	}

	scope, ok := scopes[ldapSearchServer.Scope]

	if !ok {
		log.LoggerWContext(*h.Ctx).Error("Unknow Search Scope: " + ldapSearchServer.Scope)
	}

	response, err := conn.SearchWithPaging(&ldap.SearchRequest{
		BaseDN:     ldapSearchServer.BaseDN,
		Scope:      scope,
		Filter:     ldapInfo.Search,
		Attributes: ldapInfo.Attributes,
	}, uint32(200))

	if err != nil {
		log.LoggerWContext(*h.Ctx).Error("Failed Search : " + err.Error())
	}

	_, err = json.MarshalIndent(transform(response.Entries), "", "  ")
	if err != nil {
		log.LoggerWContext(*h.Ctx).Error("Cannot unmarshall: " + err.Error())
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(transform(response.Entries)); err != nil {
		panic(err)
	}
}

func (h *Handler) connect(ldapServer *ldapServer) (conn *ldap.Conn, err error) {
	sources := ldapServer.Host
	for _, src := range sources {

		if ldapServer.Encryption != "ssl" {
			conn, err = ldap.Dial("tcp", fmt.Sprintf("%s:%s", src, ldapServer.Port))
		} else {
			conn, err = ldap.DialTLS("tcp", fmt.Sprintf("%s:%s", src, ldapServer.Port), &tls.Config{
				InsecureSkipVerify: true,
			})
		}

		if err != nil {
			log.LoggerWContext(*h.Ctx).Error("Error connecting to LDAP source: " + err.Error())
		} else {
			// Reconnect with TLS
			if ldapServer.Encryption == "starttls" {
				err = conn.StartTLS(&tls.Config{InsecureSkipVerify: true})

				if err != nil {
					log.LoggerWContext(*h.Ctx).Crit("Error connecting to LDAP source using TLS: " + err.Error())
				}
			}
		}

		if err != nil {
			return
		}
		if err = conn.Bind(ldapServer.BindDN, ldapServer.Password); err != nil {
			return
		}
		return
	}
	return
}

func transformAttribs(attribs []*ldap.EntryAttribute) map[string]interface{} {
	res := make(map[string]interface{})
	for _, attrib := range attribs {
		switch len(attrib.Values) {
		case 0:
			res[attrib.Name] = nil
		case 1:
			res[attrib.Name] = attrib.Values[0]
		default:
			res[attrib.Name] = attrib.Values
		}
	}
	return res
}

func transform(entries []*ldap.Entry) map[string]map[string]interface{} {
	res := make(map[string]map[string]interface{})
	for _, entry := range entries {
		res[entry.DN] = transformAttribs(entry.Attributes)
	}
	return res
}
