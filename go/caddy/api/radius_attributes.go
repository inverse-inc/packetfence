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
	PlaceHolder   string                 `json:"placeholder,omitempty"`
	Vendor        string                 `json:"vendor,omitempty"`
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

		appendRadiusAttributes(&results.Items, d.Attributes, d.Values, "")

		for _, v := range d.Vendors {
			appendRadiusAttributes(&results.Items, v.Attributes, v.Values, v.Name)
		}
	}

	res, _ := json.Marshal(&results)
	radiusAttributesJson = string(res)
}

func appendRadiusAttributes(items *[]RadiusAttribute, attributes []*dictionary.Attribute, values []*dictionary.Value, vendor string) {
	for _, a := range attributes {
		var allowedValues []RadiusAttributeValue
		for _, v := range dictionary.ValuesByAttribute(values, a.Name) {
			allowedValues = append(allowedValues, RadiusAttributeValue{Name: v.Name, Value: v.Number})
		}

		*items = append(*items, RadiusAttribute{Name: a.Name, AllowedValues: allowedValues, PlaceHolder: placeHolders[a.Name], Vendor: vendor})
	}
}
