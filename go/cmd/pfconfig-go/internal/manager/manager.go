// Package manager
package manager

import (
	"context"
	"errors"
	"log/slog"
	"path/filepath"
	"regexp"

	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/cache"
	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/loader"
	ns "github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/namespace"
)

type Request struct {
	Method           string `json:"method,omitempty"`
	Key              string `json:"key,omitempty"` // NAME::SPACE[::SUBNAMESPACE][(overlay)][;KEY]
	NoLastTouchCache string `json:"no_last_touch_cache,omitempty"`
	Encoding         string `json:"encoding,omitempty"` // "sereal" or "json"
	LastKey          string `json:"last_key,omitempty"`
	Search           string `json:"search,omitempty"`
	Namespace        string `json:"namespace,omitempty"`
	Light            string `json:"light,omitempty"`
	Index            int    `json:"index,omitempty"`
}

type Manager struct {
	namespaces map[string]*ns.NamespaceInfos // read only, done at startup
	cache      *cache.ShardedCache[*loader.Conf]
	confFolder string // folder path of pf conf files (usually /usr/local/pf/conf)
}

var queryRegex = regexp.MustCompile(`(\w+(?:\:\:\w+)*)(?:\((.*)\))?(?:;(\w+))?`)

type Query struct {
	Namespace string // NAME::SPACE, never empty
	Overlay   string //(OVERLAY), can be empty
	Key       string // ;KEY, can be empty
}

func ExtractQuery(s string) (Query, error) {
	data := queryRegex.FindStringSubmatch(s)
	if data == nil {
		return Query{}, errors.New("bad key format")
	}
	return Query{
		Namespace: data[1],
		Overlay:   data[2],
		Key:       data[3],
	}, nil
}

func NewManager(confFolder string, cache *cache.ShardedCache[*loader.Conf]) *Manager {
	m := Manager{
		confFolder: confFolder,
	}
	m.namespaces = make(map[string]*ns.NamespaceInfos, len(ns.NamespaceDefinitions))
	m.cache = cache
	for _, ns := range ns.NamespaceDefinitions {
		ns.Path = filepath.Clean(filepath.Join(confFolder, ns.Path))
		m.namespaces[ns.Name] = &ns
	}
	return &m
}

func (m *Manager) getCache(s string) (*loader.Conf, bool) {
	return m.cache.Get(s)
}

func (m *Manager) LoadConfigs(ctx context.Context, logger *slog.Logger) error {
	for _, v := range m.namespaces {
		conf, err := loader.LoadConf(v.Path)
		if err != nil {
			logger.ErrorContext(ctx, "Manager.Load", "err", err.Error())
			continue
		}
		if v.Build != nil {
			bd := ns.BuildData{
				Conf: conf,
			}
			if len(v.DepResources) > 0 {
				bd.Deps = make(map[string]*loader.Conf, len(v.DepResources))
			}
			if err := v.Build(&bd); err != nil {
				logger.ErrorContext(ctx, "Manager.Load", "err", err.Error())
				continue
			}
		}
	}
	return nil
}

func (m *Manager) Process(ctx context.Context, logger *slog.Logger, request Request) (any, error) {
	query, err := ExtractQuery(request.Key)
	if err != nil {
		return nil, err
	}
	conf, ok := m.getCache(query.Namespace)
	if !ok {
		// TODO: cache here
		return nil, errors.ErrUnsupported
	}
	data, err := dispatchMethod(ctx, logger, conf, request)
	if err != nil {
		return nil, err
	}
	// get the conf from the cache: ns only, no overlay no key
	// dispatch the method: use of overlay/key
	// format the output: sereal/json
	// return the data
	return data, nil
}
