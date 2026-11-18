package manager

import (
	"context"
	"errors"
	"log/slog"

	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/loader"
)

type MethodFunc func(conf *loader.Conf, request Request) (any, error)

var methodsFuncs = map[string]MethodFunc{
	"hash_element": hashElement,
	"element":      hashElement, // exact same code
}

func dispatchMethod(ctx context.Context, logger *slog.Logger, conf *loader.Conf, request Request) (any, error) {
	fun, ok := methodsFuncs[request.Method]
	if !ok {
		return nil, errors.ErrUnsupported
	}
	data, err := fun(conf, request)
	if err != nil {
		return nil, err
	}
	return data, nil
}

func hashElement(conf *loader.Conf, request Request) (any, error) {
	query, err := ExtractQuery(request.Key)
	if err != nil {
		return nil, err
	}
	if len(query.Key) == 0 {
		// whole file
	} else {
		// section
		section, err := conf.File.GetSection(query.Key)
		if err != nil {
			return nil, err
		}
		data := map[string]any{
			"element": section.KeysHash(),
		}
		return data, nil
	}
	return nil, nil
}
