package manager

import (
	"context"
	"fmt"
	"slices"
	"strconv"

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
		return nil, fmt.Errorf("requested method '%s' not supported", request.Method)
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

func asHash(data any) (*ns.HashData, error) {
	conf, ok := data.(*ns.HashData)
	if !ok {
		return nil, fmt.Errorf("namespace is not a hash (%T)", data)
	}
	return conf, nil
}

func asArray(data any) (*ns.ArrayData, error) {
	conf, ok := data.(*ns.ArrayData)
	if !ok {
		return nil, fmt.Errorf("namespace is not an array (%T)", data)
	}
	return conf, nil
}

func asScalar(data any) (*ns.ScalarData, error) {
	conf, ok := data.(*ns.ScalarData)
	if !ok {
		return nil, fmt.Errorf("namespace is not a scalar (%T)", data)
	}
	return conf, nil
}

// arrayElement returns the element at the index given in the key (NAME::SPACE;INDEX),
// or the whole array when there is no index, like the Perl server.
// An unknown index has no element (undef for the client).
func arrayElement(request Request, data any) (any, error) {
	conf, err := asArray(data)
	if err != nil {
		return nil, err
	}
	query, _ := ExtractQuery(request.Key) // already checked
	if query.Key == "" {
		return map[string]any{"element": conf.Values}, nil
	}
	index, err := strconv.Atoi(query.Key)
	if err != nil || index < 0 || index >= len(conf.Values) {
		return map[string]any{}, nil
	}
	return map[string]any{"element": conf.Values[index]}, nil
}

func arrayIndexExists(request Request, data any) (any, error) {
	conf, err := asArray(data)
	if err != nil {
		return nil, err
	}
	result := 1
	if request.Index < 0 || request.Index >= len(conf.Values) {
		result = 0
	}
	return map[string]any{"result": result}, nil
}

func arraySize(request Request, data any) (any, error) {
	conf, err := asArray(data)
	if err != nil {
		return nil, err
	}
	return map[string]any{"size": len(conf.Values)}, nil
}

// nextKey returns the key following last_key, the first key when last_key is empty,
// and nil at the end of the hash (or when last_key is unknown).
func nextKey(request Request, data any) (any, error) {
	conf, err := asHash(data)
	if err != nil {
		return nil, err
	}
	var next any
	if request.LastKey == "" {
		if len(conf.SectionsOrdered) > 0 {
			next = conf.SectionsOrdered[0]
		}
	} else if i := slices.Index(conf.SectionsOrdered, request.LastKey); i != -1 && i+1 < len(conf.SectionsOrdered) {
		next = conf.SectionsOrdered[i+1]
	}
	return map[string]any{"next_key": next}, nil
}

// keyExists checks the key sent in "search" (the "key" field holds the namespace)
func keyExists(request Request, data any) (any, error) {
	conf, err := asHash(data)
	if err != nil {
		return nil, err
	}
	tmp := 0
	if _, ok := conf.Sections[request.Search]; ok {
		tmp = 1
	}
	return map[string]int{
		"result": tmp,
	}, nil
}

func keys(request Request, data any) (any, error) {
	conf, err := asHash(data)
	if err != nil {
		return nil, err
	}
	return map[string][]string{"keys": conf.SectionsOrdered}, nil
}

// element returns the scalar requested
func element(request Request, data any) (any, error) {
	conf, err := asScalar(data)
	if err != nil {
		return nil, err
	}
	return map[string]any{"element": conf.Value}, nil
}

// hashElement returns the hash requested as a map[string]any.
// An unknown section has no element (undef for the client), like the Perl server.
func hashElement(request Request, data any) (any, error) {
	conf, err := asHash(data)
	if err != nil {
		return nil, err
	}
	query, _ := ExtractQuery(request.Key) // already checked
	if len(query.Key) == 0 {              // whole conf
		sections := make(map[string]map[string]string, len(conf.SectionsOrdered))
		for _, section := range conf.SectionsOrdered {
			sections[section] = conf.Sections[section]
		}
		return map[string]any{"element": sections}, nil
	}
	section, ok := conf.Sections[query.Key]
	if !ok {
		return map[string]any{}, nil
	}
	return map[string]any{"element": section}, nil
}
