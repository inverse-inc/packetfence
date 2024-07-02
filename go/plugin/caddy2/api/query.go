package api

import (
	"fmt"
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

	value := strings.ToLower(q.Value)
	field := q.Field
	switch q.Op {
	default:
		return nil, NewApiError(422, fmt.Sprintf("op %s is invalid", q.Op), nil)
	case "contains":
		switch field {
		default:
			return nil, NewFieldError(422, field, fmt.Sprintf("unknown field %s", field), nil)
		case "name":
			return func(ra *RadiusAttribute) bool { return strings.Contains(ra.searchName, value) }, nil
		case "vendor":
			return func(ra *RadiusAttribute) bool { return strings.Contains(ra.searchVendor, value) }, nil
		}
	case "equals":
		switch field {
		default:
			return nil, NewFieldError(422, field, fmt.Sprintf("unknown field %s", field), nil)
		case "name":
			return func(ra *RadiusAttribute) bool { return ra.searchName == value }, nil
		case "vendor":
			return func(ra *RadiusAttribute) bool { return ra.searchVendor == value }, nil
		}
	case "not_equals":
		switch field {
		default:
			return nil, NewFieldError(422, field, fmt.Sprintf("unknown field %s", field), nil)
		case "name":
			return func(ra *RadiusAttribute) bool { return ra.searchName != value }, nil
		case "vendor":
			return func(ra *RadiusAttribute) bool { return ra.searchVendor != value }, nil
		}
	case "starts_with":
		switch field {
		default:
			return nil, NewFieldError(422, field, fmt.Sprintf("unknown field %s", field), nil)
		case "name":
			return func(ra *RadiusAttribute) bool { return strings.HasPrefix(ra.searchName, value) }, nil
		case "vendor":
			return func(ra *RadiusAttribute) bool { return strings.HasPrefix(ra.searchVendor, value) }, nil
		}
	case "ends_with":
		switch field {
		default:
			return nil, NewFieldError(422, field, fmt.Sprintf("unknown field %s", field), nil)
		case "name":
			return func(ra *RadiusAttribute) bool { return strings.HasSuffix(ra.searchName, value) }, nil
		case "vendor":
			return func(ra *RadiusAttribute) bool { return strings.HasSuffix(ra.searchVendor, value) }, nil
		}
	case "not":
		if f, err := makeRadiusAttributeFilter(&q.Values[0]); err != nil {
			return nil, err
		} else {
			return func(ra *RadiusAttribute) bool { return !f(ra) }, nil
		}
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
}
