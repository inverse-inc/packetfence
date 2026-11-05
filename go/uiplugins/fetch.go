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
	manifest   *Manifest
	err        error
	expires    time.Time
	refreshing bool
}

// Fetcher fetches and validates the manifests of the registered plugins.
//
// A manifest, valid or not, is fetched once when its plugin registers. After
// that the last result is answered at once and refreshed in the background
// when it is older than TTL (errorTTL for a failure): a slow or dead plugin
// does not slow down the admin UI loads, it disappears from the list once a
// refresh fails.
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
		Client:  newClient(3 * time.Second),
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
	if err := m.Validate(f.Catalog, r.Name); err != nil {
		return nil, err
	}
	return m, nil
}

func cacheKey(r Registration) string {
	return r.Name + "|" + r.ManifestURL()
}

func (f *Fetcher) store(key string, m *Manifest, err error) {
	ttl := f.TTL
	if err != nil && ttl > errorTTL {
		ttl = errorTTL // a plugin that is starting must show up quickly
	}
	f.lock.Lock()
	defer f.lock.Unlock()
	if f.cache == nil {
		f.cache = map[string]cacheEntry{}
	}
	// the TTL starts once the answer is known, not when the request was sent
	f.cache[key] = cacheEntry{manifest: m, err: err, expires: time.Now().Add(ttl)}
}

func (f *Fetcher) get(ctx context.Context, r Registration) (*Manifest, error) {
	key := cacheKey(r)
	f.lock.Lock()
	if f.cache == nil {
		f.cache = map[string]cacheEntry{}
	}
	entry, found := f.cache[key]
	if found {
		if time.Now().After(entry.expires) && !entry.refreshing {
			entry.refreshing = true
			f.cache[key] = entry
			go func() {
				// not the request context: the refresh outlives the request,
				// the client timeout bounds it
				m, err := f.fetch(context.Background(), r)
				f.store(key, m, err)
			}()
		}
		f.lock.Unlock()
		return entry.manifest, entry.err
	}
	f.lock.Unlock()
	m, err := f.fetch(ctx, r)
	f.store(key, m, err)
	return m, err
}

// forget the plugins that are not registered anymore
func (f *Fetcher) prune(registrations map[string]Registration) {
	keys := map[string]bool{}
	for name, r := range registrations {
		if r.Name == "" {
			r.Name = name
		}
		keys[cacheKey(r)] = true
	}
	f.lock.Lock()
	defer f.lock.Unlock()
	for key := range f.cache {
		if !keys[key] {
			delete(f.cache, key)
		}
	}
}

// Plugins returns the plugins whose manifest could be fetched and is valid,
// sorted by name. The others are logged and left out: a plugin that stopped
// without deregistering disappears from the UI.
func (f *Fetcher) Plugins(ctx context.Context, registrations map[string]Registration) []Plugin {
	var wg sync.WaitGroup
	var lock sync.Mutex
	plugins := []Plugin{}
	for name, r := range registrations {
		if r.Name == "" {
			r.Name = name
		}
		wg.Add(1)
		go func(r Registration) {
			defer wg.Done()
			if err := r.Validate(); err != nil {
				f.log(ctx, fmt.Sprintf("UI plugin %q ignored: %s", r.Name, err))
				return
			}
			m, err := f.get(ctx, r)
			if err != nil {
				f.log(ctx, fmt.Sprintf("UI plugin %q ignored: %s", r.Name, err))
				return
			}
			lock.Lock()
			plugins = append(plugins, Plugin{ID: r.Name, Manifest: m})
			lock.Unlock()
		}(r)
	}
	wg.Wait()
	f.prune(registrations)
	sort.Slice(plugins, func(i, j int) bool { return plugins[i].ID < plugins[j].ID })
	return plugins
}

func (f *Fetcher) log(ctx context.Context, msg string) {
	if f.Log != nil {
		f.Log(ctx, msg)
	}
}

// Manifest returns the valid manifest of a registered plugin, from the cache
// like Plugins, nil when it cannot be fetched or is invalid
func (f *Fetcher) Manifest(ctx context.Context, r Registration) *Manifest {
	if err := r.Validate(); err != nil {
		return nil
	}
	m, err := f.get(ctx, r)
	if err != nil {
		return nil
	}
	return m
}
