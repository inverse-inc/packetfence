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
	namespaces map[string]*ns.NamespaceInfos // read only, done at startup
	cache      *cache.ShardedCache[string, *loader.Conf]
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

func NewManager(confFolder string, cache *cache.ShardedCache[string, *loader.Conf]) *Manager {
	m := Manager{
		confFolder: confFolder,
		namespaces: make(map[string]*ns.NamespaceInfos, len(ns.NamespaceDefinitions)),
		cache:      cache,
	}
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
		conf, err := loader.LoadConf(tmp.Path)
		if err != nil {
			logger.ErrorContext(ctx, "Manager.Load", "err", err.Error())
			continue
		}
		if tmp.Build != nil {
			bd := ns.BuildData{
				Conf: conf,
				// any overlay params here too
			}
			if len(tmp.DepResources) > 0 {
				bd.Deps = make(map[string]*loader.Conf, len(tmp.DepResources))
				for _, dep := range tmp.DepResources {
					c, ok := m.cache.Get(dep)
					if !ok { // shouldn't happen at first full build, since graph is checked already
						return fmt.Errorf("not dep %s in cache", dep)
					}
					bd.Deps[dep] = c
				}
			}
			if err := tmp.Build(&bd); err != nil {
				logger.ErrorContext(ctx, "Manager.Load", "err", err.Error())
				continue
			}
		}
		if err := m.cache.Set(ctx, key, conf, 1000); err != nil {
			return nil
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
		// not in cache or expired, build it
		logger.InfoContext(ctx, "unsupported", "ns", query.Namespace)
		return nil, errors.ErrUnsupported
	}
	data, err := dispatchMethod(ctx, logger, conf, request)
	if err != nil {
		return nil, err
	}
	return data, nil
}
