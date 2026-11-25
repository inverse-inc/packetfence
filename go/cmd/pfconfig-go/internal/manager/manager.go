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
	"strings"

	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/cache"
	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/loader"
	ns "github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/namespace"
)

type Request struct {
	Method           string `json:"method,omitempty"`
	Key              string `json:"key,omitempty"`      // NAME::SPACE[::SUBNAMESPACE][(overlay)][;KEY]
	Encoding         string `json:"encoding,omitempty"` // "sereal" or "json"
	LastKey          string `json:"last_key,omitempty"`
	Namespace        string `json:"namespace,omitempty"`
	NoLastTouchCache string `json:"no_last_touch_cache,omitempty"`
	Search           string `json:"search,omitempty"`
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

type Query struct {
	Namespace string // NAME::SPACE, never empty
	Overlay   string //(OVERLAY), can be empty
	Key       string // ;KEY, can be empty
	CacheKey  string // Namespace + (Overlay)
}

// namespaceRegex matches NAME::SPACE[(OVERLAY)], the part of the query key before the first ';'
var namespaceRegex = regexp.MustCompile(`^(\w+(?:::\w+)*)(?:\(([^()]*)\))?$`)

// ExtractQuery splits a query key NAME::SPACE[(OVERLAY)][;KEY].
// Like the Perl server, everything after the first ';' is the key: section names
// can contain any character ('.', '-', ' ', '/', ...).
func ExtractQuery(s string) (Query, error) {
	nsPart, key, _ := strings.Cut(s, ";")
	data := namespaceRegex.FindStringSubmatch(nsPart)
	if data == nil {
		return Query{}, fmt.Errorf("bad query key format '%s'", s)
	}
	cacheKey := data[1]
	if len(data[2]) > 0 {
		cacheKey += "(" + data[2] + ")"
	}
	return Query{
		Namespace: data[1],
		Overlay:   data[2],
		Key:       key,
		CacheKey:  cacheKey,
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
		if ns.Path != nil { // a conf file
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
	return m.reloadAllConfs(ctx)
}

func (m *Manager) reloadAllConfs(ctx context.Context) error {
	if m.nsGraph == nil {
		return errors.New("preload namespaces first")
	}
	for _, key := range m.nsGraph.GetNodes() {
		tmp, _ := m.namespaces[key] // key exists at this point
		conf, err := loadBaseConf(tmp)
		if err != nil {
			return err
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
					if !ok { // topological order ensure we have the dependencies
						// error here means bad namespace definition or cyclic dep, already check before
						return fmt.Errorf("no dependency %s in cache", dep)
					}
					bd.Deps[dep] = c
				}
			}
			data, err = tmp.Build(&bd)
			if err != nil {
				return err
			}
		}
		if err := m.cache.Set(ctx, key, data); err != nil {
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
	if _, supported := m.namespaces[query.Namespace]; !supported {
		// if namespace not supported, proxy to Perl pfconfig
		return nil, errors.ErrUnsupported
	}
	namespace, ok := m.getCache(query.CacheKey)
	if !ok {
		// new overlay
		return nil, fmt.Errorf("no %s in cache", query.CacheKey)
	}
	// check for validity
	data, err := m.dispatchMethod(ctx, request, namespace)
	if err != nil {
		return nil, err
	}
	return data, nil
}
