package main

import (
	"encoding/json"
	"fmt"
	"github.com/inverse-inc/go-radius/dictionary"
	"os"
	"strconv"
)

type Attrs map[string][2]string
type RAttrs map[int][2]string
type ValuesVal map[string]uint
type RValuesVal map[uint]string
type Values map[int]ValuesVal
type RValues map[int]RValuesVal
type RadiusDictPerl struct {
	Vendors   map[string]uint    `json:"vendors"`
	AVendors  map[string]string  `json:"avendors"`
	VsAttrs   map[uint]Attrs     `json:"vsattr"`
	Attrs     Attrs              `json:"attr"`
	RAttrs    RAttrs             `json:"rattr"`
	RVAttrs   map[uint]RAttrs    `json:"rvsattr"`
	Values    Values             `json:"val"`
	RValues   RValues            `json:"rval"`
	VSValues  map[uint]Values    `json:"vsaval"`
	RVSValues map[uint]RValues   `json:"rvsaval"`
}

func AddValues(dictValues Values, dictRValues RValues, attrs []*dictionary.Attribute, dValues []*dictionary.Value) {
	for _, v := range dValues {
		a := dictionary.AttributeByName(attrs, v.Attribute)
		if a == nil {
			continue
		}
		var values ValuesVal
		var rvalues RValuesVal
		var found bool
		if values, found = dictValues[a.OID[0]]; !found {
			values = make(ValuesVal)
			dictValues[a.OID[0]] = values
		}

		values[v.Name] = v.Number

		if rvalues, found = dictRValues[a.OID[0]]; !found {
			rvalues = make(RValuesVal)
			dictRValues[a.OID[0]] = rvalues
		}

		rvalues[v.Number] = v.Name
	}
}

func main() {
	parser := &dictionary.Parser{
		Opener: &dictionary.FileSystemOpener{
			Root: "/usr/share/freeradius",
		},
		IgnoreIdenticalAttributes:  true,
		IgnoreUnknownAttributeType: true,
	}

	d, err := parser.ParseFile("/usr/local/pf/lib/pf/util/combined_dictionary")
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	dict := RadiusDictPerl{
		Vendors:   make(map[string]uint),
		AVendors:  make(map[string]string),
		VsAttrs:   make(map[uint]Attrs),
		Attrs:     make(Attrs),
		RVAttrs:   make(map[uint]RAttrs),
		RAttrs:    make(RAttrs),
		Values:    make(Values),
		RValues:   make(RValues),
		VSValues:  make(map[uint]Values),
		RVSValues: make(map[uint]RValues),
	}

	AddValues(dict.Values, dict.RValues, d.Attributes, d.Values)
	for _, a := range d.Attributes {
		aType := a.Type.String()
		dict.Attrs[a.Name] = [2]string{strconv.FormatUint(uint64(a.OID[0]), 10), aType}
		dict.RAttrs[a.OID[0]] = [2]string{a.Name, aType}
	}

	for _, v := range d.Vendors {
		dict.Vendors[v.Name] = v.Number
		vsAttrs := make(Attrs)
		rvAttrs := make(RAttrs)

		for _, a := range v.Attributes {
			dict.AVendors[a.Name] = v.Name
			aType := a.Type.String()
			vsAttrs[a.Name] = [2]string{strconv.FormatUint(uint64(a.OID[0]), 10), aType}
			rvAttrs[a.OID[0]] = [2]string{a.Name, aType}
		}

		dict.VsAttrs[v.Number] = vsAttrs
		dict.RVAttrs[v.Number] = rvAttrs
		if len(v.Values) > 0 {
			Values := make(Values)
			RValues := make(RValues)
			AddValues(Values, RValues, v.Attributes, v.Values)
			dict.VSValues[v.Number] = Values
			dict.RVSValues[v.Number] = RValues
		}

	}

	b, err := json.Marshal(&dict)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	fmt.Print(string(b))
}
