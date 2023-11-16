package types

import (
	"context"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/gorilla/schema"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"gorm.io/gorm"
)

type (
	Type int

	// Info struct
	Info struct {
		Status      int         `json:"status"`
		Password    string      `json:"password"`
		Error       string      `json:"error"`
		ContentType string      `json:"contentType"`
		Raw         []byte      `json:"raw"`
		Entries     interface{} `json:"items"`
		NextCursor  int         `json:"nextCursor"`
		PrevCursor  int         `json:"prevCursor"`
		TotalCount  int         `json:"total_count"`
		Serial      string      `json:"serial"`
	}

	// Create interface
	Create interface {
		new() error
		get() error
		revoke() error
	}

	// Error struct
	Error struct {
		Field   string `json:"field"`
		Message string `json:"message"`
	}
	// Errors struct
	Errors struct {
		Errors  []Error `json:"errors"`
		Message string  `json:"message"`
		Status  int     `json:"status"`
	}
	// Handler struct
	Handler struct {
		Next   httpserver.Handler
		Router *chi.Mux
		DB     *gorm.DB
		Ctx    *context.Context
	}
)

var decoder = schema.NewDecoder()

func DecodeUrlQuery(req *http.Request) (sql.Vars, error) {
	vars := sql.Vars{}
	if err := decoder.Decode(&vars, req.URL.Query()); err != nil {
		return vars, err
	}
	if len(vars.Fields) > 0 {
		fields := make([]string, 0)
		for _, field := range vars.Fields {
			for _, item := range strings.Split(field, ",") {
				fields = append(fields, strings.Trim(item, " "))
			}
		}
		vars.Fields = fields
	}
	if len(vars.Sort) > 0 {
		sorts := make([]string, 0)
		for _, sort := range vars.Sort {
			for _, item := range strings.Split(sort, ",") {
				sorts = append(sorts, strings.Trim(item, " "))
			}
		}
		vars.Sort = sorts
	}
	return vars, nil
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

type contextKey int

const varsKey contextKey = iota

func Vars(r *http.Request) map[string]string {
	if rv := r.Context().Value(varsKey); rv != nil {
		return rv.(map[string]string)
	}
	return nil
}
