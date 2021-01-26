package pfpki

import (
	"encoding/json"
	"io/ioutil"
	"net/http"
	"strings"

	"github.com/gorilla/schema"
)

type (
	Vars struct {
		Cursor int      `schema:"cursor" json:"cursor" default:"0"`
		Limit  int      `schema:"limit" json:"limit" default:"100"`
		Fields []string `schema:"fields" json:"fields" default:"id"`
		Sort   []string `schema:"sort" json:"sort" default:"id ASC"`
		Query  Search   `schema:"query" json:"query"`
	}

	// Search struct
	Search struct {
		Field  string      `schema:"field" json:"field,omitempty"`
		Op     string      `schema:"op" json:"op"`
		Value  interface{} `schema:"value" json:"value,omitempty"`
		Values []Search    `schema:"values" json:"values,omitempty"`
	}
)

var decoder = schema.NewDecoder()

func DecodeUrlQuery(req *http.Request) (Vars, error) {
	vars := Vars{}
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

func (vars *Vars) DecodeBodyJson(req *http.Request) error {
	body, err := ioutil.ReadAll(req.Body)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(body, &vars); err != nil {
		return err
	}
	return nil
}
