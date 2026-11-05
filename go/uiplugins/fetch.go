package uiplugins

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"sort"
	"sync"
	"time"
)

// maximum size of a manifest
const maxManifestSize = 1 << 20

// how long a failure is cached
const errorTTL = 5 * time.Second

// Plugin is a registered plugin with its valid manifest
type Plugin struct {
	ID       string    `json:"id"`
	Manifest *Manifest `json:"manifest"`
}

type cacheEntry struct {
	manifest *Manifest
	err      error
	expires  time.Time
}

// Fetcher fetches and validates the manifests of the registered plugins.
// Results, valid or not, are cached for TTL so a slow or dead plugin does not
// slow down every admin UI load.
type Fetcher struct {
	Client  *http.Client
	Catalog *Catalog
	TTL     time.Duration
	// Log receives the reason a plugin is left out
	Log func(ctx context.Context, msg string)

	lock  sync.Mutex
	cache map[string]cacheEntry
}

func NewFetcher(log func(ctx context.Context, msg string)) *Fetcher {
	return &Fetcher{
		Client:  &http.Client{Timeout: 3 * time.Second},
		Catalog: DefaultCatalog,
		TTL:     30 * time.Second,
		Log:     log,
	}
}

func (f *Fetcher) fetch(ctx context.Context, r Registration) (*Manifest, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, r.ManifestURL(), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")
	resp, err := f.Client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("%s answered %d", r.ManifestURL(), resp.StatusCode)
	}
	b, err := io.ReadAll(io.LimitReader(resp.Body, maxManifestSize+1))
	if err != nil {
		return nil, err
	}
	if len(b) > maxManifestSize {
		return nil, fmt.Errorf("manifest larger than %d bytes", maxManifestSize)
	}
	m, err := ParseManifest(b)
	if err != nil {
		return nil, err
	}
	if err := m.Validate(f.Catalog, r.ID); err != nil {
		return nil, err
	}
	return m, nil
}

func (f *Fetcher) get(ctx context.Context, r Registration) (*Manifest, error) {
	key := r.ID + "|" + r.ManifestURL()
	now := time.Now()
	f.lock.Lock()
	if f.cache == nil {
		f.cache = map[string]cacheEntry{}
	}
	entry, found := f.cache[key]
	f.lock.Unlock()
	if found && now.Before(entry.expires) {
		return entry.manifest, entry.err
	}
	m, err := f.fetch(ctx, r)
	ttl := f.TTL
	if err != nil && ttl > errorTTL {
		ttl = errorTTL // a plugin that is starting must show up quickly
	}
	f.lock.Lock()
	f.cache[key] = cacheEntry{manifest: m, err: err, expires: now.Add(ttl)}
	f.lock.Unlock()
	return m, err
}

// Plugins returns the plugins whose manifest could be fetched and is valid,
// sorted by id. The others are logged and left out: a plugin that stopped
// without deregistering disappears from the UI.
func (f *Fetcher) Plugins(ctx context.Context, registrations map[string]Registration) []Plugin {
	var wg sync.WaitGroup
	var lock sync.Mutex
	plugins := []Plugin{}
	for id, r := range registrations {
		if r.ID == "" {
			r.ID = id
		}
		wg.Add(1)
		go func(r Registration) {
			defer wg.Done()
			if err := r.Validate(); err != nil {
				f.log(ctx, fmt.Sprintf("UI plugin %q ignored: %s", r.ID, err))
				return
			}
			m, err := f.get(ctx, r)
			if err != nil {
				f.log(ctx, fmt.Sprintf("UI plugin %q ignored: %s", r.ID, err))
				return
			}
			lock.Lock()
			plugins = append(plugins, Plugin{ID: r.ID, Manifest: m})
			lock.Unlock()
		}(r)
	}
	wg.Wait()
	sort.Slice(plugins, func(i, j int) bool { return plugins[i].ID < plugins[j].ID })
	return plugins
}

func (f *Fetcher) log(ctx context.Context, msg string) {
	if f.Log != nil {
		f.Log(ctx, msg)
	}
}
