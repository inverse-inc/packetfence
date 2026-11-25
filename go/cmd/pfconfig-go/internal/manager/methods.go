package manager

import (
	"context"
	"errors"
	"fmt"

	ns "github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/namespace"
)

type MethodFunc func(request Request, data any) (any, error)

var methodsFuncs = map[string]MethodFunc{
	"hash_element":       hashElement,
	"element":            element, // proxy to hashElement
	"keys":               keys,
	"key_exists":         keyExists,
	"next_key":           nextKey,
	"array_element":      arrayElement,
	"array_size":         arraySize,
	"array_index_exists": arrayIndexExists,
	"expire":             expire,
}

func (m *Manager) dispatchMethod(ctx context.Context, request Request, namespace any) (any, error) {
	fun, ok := methodsFuncs[request.Method]
	if !ok {
		return nil, errors.ErrUnsupported
	}
	return fun(request, namespace)
}

func expire(request Request, data any) (any, error) {
	if request.Namespace == "__all__" {
		// expire all
	} else {
	}
	return map[string]string{"status": "OK."}, nil
}

func arrayElement(request Request, data any) (any, error) {
	conf := data.(*ns.ArrayData)
	if request.Index < 0 || request.Index >= len(conf.Values) {
		return map[string]any{"element": nil}, fmt.Errorf("out of bound index %d", request.Index)
	}
	return map[string]any{"element": conf.Values[request.Index]}, nil
}

func arrayIndexExists(request Request, data any) (any, error) {
	conf := data.(*ns.ArrayData)
	result := 1
	if request.Index < 0 || request.Index >= len(conf.Values) {
		result = 0
	}
	return map[string]any{"result": result}, nil
}

func arraySize(request Request, data any) (any, error) {
	conf := data.(*ns.ArrayData)
	return map[string]any{"size": len(conf.Values)}, nil
}

func nextKey(request Request, data any) (any, error) {
	var nextKey any
	conf := data.(*ns.HashData)
	i := 0
	if len(request.LastKey) == 0 {
		nextKey = conf.SectionsOrdered[0]
	} else {
		for _, k := range conf.SectionsOrdered {
			i += 1
			if k == request.Key {
				break
			}
		}
		if i >= len(conf.SectionsOrdered) {
			nextKey = nil
		} else {
			nextKey = conf.SectionsOrdered[i]
		}
	}
	return map[string]any{"next_key": nextKey}, nil
}

func keyExists(request Request, data any) (any, error) {
	conf := data.(*ns.HashData)
	tmp := 0
	if _, ok := conf.Sections[request.Key]; ok {
		tmp = 1
	}
	return map[string]int{
		"result": tmp,
	}, nil
}

func keys(request Request, data any) (any, error) {
	conf := data.(*ns.HashData)
	return map[string][]string{"keys": conf.SectionsOrdered}, nil
}

// element returns the scalar requested
func element(request Request, data any) (any, error) {
	conf := data.(*ns.ScalarData)
	return map[string]any{"element": conf.Value}, nil
}

// hashElement returns the hash requested as a map[string]any
func hashElement(request Request, data any) (any, error) {
	query, err := ExtractQuery(request.Key)
	if err != nil {
		return nil, err
	}
	conf := data.(*ns.HashData)
	tmp := map[string]any{
		"element": nil,
	}
	if len(query.Key) == 0 { // whole conf
		sections := make(map[string]map[string]string, len(conf.SectionsOrdered))
		for _, section := range conf.SectionsOrdered {
			v := conf.Sections[section]
			sections[section] = v
		}
		tmp["element"] = sections
	} else { // section
		section, ok := conf.Sections[query.Key]
		if !ok {
			return nil, fmt.Errorf("section %s does not exists", query.Key)
		}
		tmp["element"] = section
	}
	return tmp, nil
}
