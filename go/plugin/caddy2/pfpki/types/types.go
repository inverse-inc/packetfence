package types

import (
	"context"
	"net/http"
	"strings"

	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/go-chi/chi/v5"
	"github.com/gorilla/schema"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
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

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	ctx := r.Context()
	defer panichandler.Http(ctx, w)
	rctx := chi.NewRouteContext()
	ctx = context.WithValue(ctx, rctx, chi.RouteCtxKey)
	r = r.WithContext(ctx)
	rctx.Routes = h.Router
	if h.Router.Match(rctx, r.Method, r.URL.Path) {
		h.Router.ServeHTTP(w, r)

		// TODO change me and wrap actions into something that handles server errors
		return nil
	}

	return next.ServeHTTP(w, r)
}

func Params(r *http.Request, keys ...string) map[string]string {
	param := make(map[string]string)
	for _, key := range keys {
		value := chi.URLParam(r, key)
		if value != "" {
			param[key] = value
		}
	}
	return param
}
