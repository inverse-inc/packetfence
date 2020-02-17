package api

import (
	"encoding/json"
	"fmt"
	"github.com/inverse-inc/go-radius/dictionary"
	"github.com/julienschmidt/httprouter"
	"net/http"
)

var radiusAttributesJson string

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

func (h APIHandler) radiusAttributes(w http.ResponseWriter, r *http.Request, p httprouter.Params) {

	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, radiusAttributesJson)
}

func setupRadiusDictionary() {
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
}
