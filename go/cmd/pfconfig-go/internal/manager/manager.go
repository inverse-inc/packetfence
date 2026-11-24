// Package manager
package manager

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"maps"
	"path/filepath"
	"regexp"
	"slices"

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
	logger     *slog.Logger
	namespaces map[string]*ns.NamespaceInfos // read only, done at startup
	cache      *cache.ShardedCache[string, any]
	nsGraph    *Graph
	confFolder string // folder path of pf conf files (usually /usr/local/pf/conf)
}

var queryRegex = regexp.MustCompile(`(\w+(?:\:\:\w+)*)(?:\((.*)\))?(?:;([:\w]+))?`)

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

func NewManager(logger *slog.Logger, confFolder string, cache *cache.ShardedCache[string, any]) *Manager {
	m := Manager{
		confFolder: confFolder,
		namespaces: make(map[string]*ns.NamespaceInfos, len(ns.NamespaceDefinitions)),
		cache:      cache,
		logger:     logger,
	}
	for _, ns := range ns.NamespaceDefinitions {
		if ns.Path != nil { // not a conf::
			ns.Path = new(filepath.Clean(filepath.Join(confFolder, *ns.Path)))
		}
		m.namespaces[ns.Name] = &ns
	}
	return &m
}

func (m *Manager) getCache(s string) (any, bool) {
	return m.cache.Get(s)
}

func loadBaseConf(nsInfos *ns.NamespaceInfos) (any, error) {
	switch nsInfos.Type() {
	case ns.NamespaceConfig:
		// .Path pointer has been checked already
		return loader.LoadConf(*nsInfos.Path)
	default:
		return nil, nil
	}
}

func (m *Manager) LoadConfigs(ctx context.Context) error {
	graph, err := NamespacesToGraph(slices.Collect(maps.Values(m.namespaces)))
	if err != nil {
		return err
	}
	err = graph.TopologicalOrder()
	if err != nil {
		return err
	}
	m.nsGraph = graph
	for _, key := range graph.GetNodes() {
		tmp, _ := m.namespaces[key] // key exists at this point
		conf, err := loadBaseConf(tmp)
		if err != nil {
			m.logger.ErrorContext(ctx, "Manager.Load", "err", err.Error())
			continue
		}
		var data any
		if tmp.Build != nil {
			bd := ns.BuildData{
				Data: conf,
			}
			if len(tmp.DepResources) > 0 {
				bd.Deps = make(map[string]any, len(tmp.DepResources))
				for _, dep := range tmp.DepResources {
					c, ok := m.cache.Get(dep)
					if !ok { // shouldn't happen at first full build, since graph is checked already
						return fmt.Errorf("not dep %s in cache", dep)
					}
					bd.Deps[dep] = c
				}
			}
			data, err = tmp.Build(&bd)
			if err != nil {
				return err
			}
		}
		if err := m.cache.Set(ctx, key, data, 1000); err != nil {
			return err
		}
	}
	return nil
}

func (m *Manager) Process(ctx context.Context, request Request) (any, error) {
	query, err := ExtractQuery(request.Key)
	if err != nil {
		return nil, err
	}
	namespace, ok := m.getCache(query.Namespace)
	if !ok {
		// not in cache or expired, build it
		m.logger.InfoContext(ctx, "unsupported", "ns", query.Namespace)
		return nil, errors.ErrUnsupported
	}
	data, err := m.dispatchMethod(ctx, request, namespace)
	if err != nil {
		m.logger.InfoContext(ctx, "unsupported", request.Key, request.Method)
		return nil, err
	}
	return data, nil
}
