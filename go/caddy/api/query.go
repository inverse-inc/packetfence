package api

import (
	"strings"
)

type Query struct {
	Field  string  `json:"field"`
	Op     string  `json:"op"`
	Value  string  `json:"value"`
	Values []Query `json:"values"`
}

func radisAttributesFilterFalse(ra *RadiusAttribute) bool {
	return false
}

func radisAttributesFilterTrue(ra *RadiusAttribute) bool {
	return true
}

func makeRadiusAttributeFilter(q *Query) (func(ra *RadiusAttribute) bool, error) {
	if q == nil {
		return radisAttributesFilterTrue, nil
	}

	value := q.Value
	switch q.Op {
	case "contains":
		return func(ra *RadiusAttribute) bool { return strings.Contains(ra.Name, value) }, nil
	case "equals":
		return func(ra *RadiusAttribute) bool { return ra.Name == value }, nil
	case "not_equals":
		return func(ra *RadiusAttribute) bool { return ra.Name != value }, nil
	case "starts_with":
		return func(ra *RadiusAttribute) bool { return strings.HasPrefix(ra.Name, value) }, nil
	case "ends_with":
		return func(ra *RadiusAttribute) bool { return strings.HasSuffix(ra.Name, value) }, nil
	case "not":
		f, _ := makeRadiusAttributeFilter(&q.Values[0])
		return func(ra *RadiusAttribute) bool { return !f(ra) }, nil
	case "or":
		funcs := []func(ra *RadiusAttribute) bool{}
		for _, sq := range q.Values {
			f, err := makeRadiusAttributeFilter(&sq)
			if err != nil {
				return nil, err
			}

			funcs = append(funcs, f)
		}
		return func(ra *RadiusAttribute) bool {
				for _, f := range funcs {
					if f(ra) {
						return true
					}
				}
				return false
			},
			nil
	case "and":
		funcs := []func(ra *RadiusAttribute) bool{}
		for _, sq := range q.Values {
			f, err := makeRadiusAttributeFilter(&sq)
			if err != nil {
				return nil, err
			}

			funcs = append(funcs, f)
		}
		return func(ra *RadiusAttribute) bool {
				for _, f := range funcs {
					if !f(ra) {
						return false
					}
				}
				return true
			},
			nil
	case "true":
		return radisAttributesFilterTrue, nil
	}

	return radisAttributesFilterFalse, nil
}
