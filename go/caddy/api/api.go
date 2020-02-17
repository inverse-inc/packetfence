package api

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/inverse-inc/go-radius/dictionary"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/julienschmidt/httprouter"
	"net/http"
)

var radiusAttributesJson string

// Register the plugin in caddy
func init() {
	caddy.RegisterPlugin("api", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

type APIHandler struct {
	Next   httpserver.Handler
	router *httprouter.Router
}

type RadiusAttributeValue struct {
	Name  string `json:"name"`
	Value uint   `json:"value"`
}

type RadiusAttribute struct {
	Name          string                 `json:"name"`
	AllowedValues []RadiusAttributeValue `json:"allowed_values"`
}

type RadiusAttributesResults struct {
	Items []RadiusAttribute `json:"items"`
}

// Setup the api middleware
// Also loads the pfconfig resources and registers them in the pool
func setup(c *caddy.Controller) error {
	ctx := log.LoggerNewContext(context.Background())

	handler, err := buildHandler(ctx)

	if err != nil {
		return err
	}

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		handler.Next = next
		return handler
	})

	parser := &dictionary.Parser{
		Opener: &dictionary.FileSystemOpener{
			Root: "/usr/share/freeradius",
		},
		IgnoreIdenticalAttributes:  true,
		IgnoreUnknownAttributeType: true,
	}

	results := RadiusAttributesResults{}

	d, err := parser.ParseFile("dictionary")
	if err != nil {
		fmt.Println(err)
	} else {

		for _, a := range d.Attributes {
			var values []RadiusAttributeValue
			for _, v := range dictionary.ValuesByAttribute(d.Values, a.Name) {
				values = append(values, RadiusAttributeValue{Name: v.Name, Value: v.Number})
			}

			results.Items = append(results.Items, RadiusAttribute{Name: a.Name, AllowedValues: values})
		}

		for _, v := range d.Vendors {
			for _, a := range v.Attributes {
				results.Items = append(results.Items, RadiusAttribute{Name: a.Name})
			}
		}
	}

	res, _ := json.Marshal(&results)
	radiusAttributesJson = string(res)
	return nil
}

// Build the Handler which will initialize the routes
func buildHandler(ctx context.Context) (APIHandler, error) {

	apiHandler := APIHandler{}
	router := httprouter.New()
	router.GET("/api/v1/radius_attributes", apiHandler.radiusattributes)

	apiHandler.router = router

	return apiHandler, nil
}

func (h APIHandler) radiusattributes(w http.ResponseWriter, r *http.Request, p httprouter.Params) {

	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, radiusAttributesJson)
}

func (h APIHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()

	defer panichandler.Http(ctx, w)

	// We always default to application/json
	w.Header().Set("Content-Type", "application/json")

	if handle, params, _ := h.router.Lookup(r.Method, r.URL.Path); handle != nil {
		handle(w, r, params)
		return 0, nil
	} else {
		return h.Next.ServeHTTP(w, r)
	}

}
