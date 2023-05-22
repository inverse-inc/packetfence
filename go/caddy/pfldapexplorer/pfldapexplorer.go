package pfldapexplorer

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"time"

	"github.com/gorilla/mux"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"gopkg.in/ldap.v2"
)

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
	pfldapexplorer.Refresh(ctx)
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

	pfldapexplorer.Router = mux.NewRouter()
	PFLdapExplorer := &pfldapexplorer
	api := pfldapexplorer.Router.PathPrefix("/api/v1").Subrouter()

	api.Handle("/ldap/search", pfldapexplorer.SearchLDAP(PFLdapExplorer)).Methods("POST")

	return pfldapexplorer, nil

}

// Handler struct
type Handler struct {
	Next   httpserver.Handler
	Router *mux.Router
	Ctx    *context.Context
}

type Search struct {
	Server     string   `json:"server"`
	Search     string   `json:"search"`
	Attributes []string `json:"attributes,omitempty"`
}

type Sources struct {
	Sources map[string]*pfconfigdriver.AuthenticationSourceLdap
}

var (
	scopes = map[string]int{
		"base": ldap.ScopeBaseObject,
		"one":  ldap.ScopeSingleLevel,
		"sub":  ldap.ScopeWholeSubtree,
	}
)

var LdapSources *Sources

func (h Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()
	r = r.WithContext(ctx)

	defer panichandler.Http(ctx, w)

	routeMatch := mux.RouteMatch{}
	if h.Router.Match(r, &routeMatch) {
		h.Router.ServeHTTP(w, r)

		// TODO change me and wrap actions into something that handles server errors
		return 0, nil
	}
	return h.Next.ServeHTTP(w, r)
}

// Refresh the configuration
func (h Handler) Refresh(ctx context.Context) {
	LdapSources = &Sources{}
	LdapSources.readConfig(ctx)
}

func (s *Sources) readConfig(ctx context.Context) {

	var sections pfconfigdriver.PfconfigKeys
	sections.PfconfigNS = "resource::authentication_sources_ldap"
	sources := make(map[string]*pfconfigdriver.AuthenticationSourceLdap)
	pfconfigdriver.FetchDecodeSocket(ctx, &sections)
	for _, src := range sections.Keys {
		var source pfconfigdriver.AuthenticationSourceLdap
		source.PfconfigNS = "resource::authentication_sources_ldap"
		source.PfconfigHashNS = src
		pfconfigdriver.FetchDecodeSocket(ctx, &source)
		sources[src] = &source
		s.Sources = sources
	}
}

func (h *Handler) SearchLDAP(pfldapexporer *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		var LdapSearch = Search{}
		body, err := ioutil.ReadAll(req.Body)
		if err != nil {
			log.LoggerWContext(*h.Ctx).Info(err.Error())
		}

		if err = json.Unmarshal(body, &LdapSearch); err != nil {
			log.LoggerWContext(*h.Ctx).Info(err.Error())
		}
		h.search(&LdapSearch, res, req)
	})
}

func (h *Handler) search(ldapInfo *Search, res http.ResponseWriter, req *http.Request) {

	conn, err := h.connect(ldapInfo.Server)

	defer conn.Close()

	if err != nil {
		log.LoggerWContext(*h.Ctx).Error("Error connecting to LDAP source: " + err.Error())
	}

	scope, ok := scopes[LdapSources.Sources[ldapInfo.Server].Scope]

	if !ok {
		log.LoggerWContext(*h.Ctx).Error("Unknow Search Scope: " + LdapSources.Sources[ldapInfo.Server].Scope)
	}

	response, err := conn.SearchWithPaging(&ldap.SearchRequest{
		BaseDN:     LdapSources.Sources[ldapInfo.Server].BaseDN,
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

func (h *Handler) connect(id string) (conn *ldap.Conn, err error) {
	sources := LdapSources.Sources[id].Host
	for _, src := range sources {

		if LdapSources.Sources[id].Encryption != "ssl" {
			conn, err = ldap.Dial("tcp", fmt.Sprintf("%s:%s", src, LdapSources.Sources[id].Port))
		} else {
			conn, err = ldap.DialTLS("tcp", fmt.Sprintf("%s:%s", src, LdapSources.Sources[id].Port), &tls.Config{
				InsecureSkipVerify: true,
			})
		}

		if err != nil {
			log.LoggerWContext(*h.Ctx).Error("Error connecting to LDAP source: " + err.Error())
		} else {
			// Reconnect with TLS
			if LdapSources.Sources[id].Encryption == "starttls" {
				err = conn.StartTLS(&tls.Config{InsecureSkipVerify: true})

				if err != nil {
					log.LoggerWContext(*h.Ctx).Crit("Error connecting to LDAP source using TLS: " + err.Error())
				}
			}
		}

		if err != nil {
			return
		}
		if err = conn.Bind(LdapSources.Sources[id].BindDN, LdapSources.Sources[id].Password); err != nil {
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
