package db

import (
	"context"
	"errors"
	"sync"
	"testing"
)

// sql.Open does not connect, so none of these tests need a live database.

func TestCachedConnectURIReturnsSamePoolForSameDSN(t *testing.T) {
	ctx := context.Background()
	uri := ReturnURI(ctx, "pf", "secret", "100.64.0.1", "6033", "pf_cache_same")

	a, err := cachedConnectURI(ctx, uri)
	if err != nil {
		t.Fatalf("first open: %v", err)
	}
	b, err := cachedConnectURI(ctx, uri)
	if err != nil {
		t.Fatalf("second open: %v", err)
	}
	if a != b {
		t.Fatal("same DSN returned two different pools")
	}
	if got := a.Stats().MaxOpenConnections; got != poolMaxOpen() {
		t.Fatalf("pool limits not applied: MaxOpenConnections=%d want %d", got, poolMaxOpen())
	}
}

func TestCachedConnectURIDistinguishesDSNs(t *testing.T) {
	ctx := context.Background()
	base, err := cachedConnectURI(ctx, ReturnURI(ctx, "pf", "secret", "100.64.0.1", "6033", "pf_cache_a"))
	if err != nil {
		t.Fatal(err)
	}
	for name, uri := range map[string]string{
		"dbName":   ReturnURI(ctx, "pf", "secret", "100.64.0.1", "6033", "pf_cache_b"),
		"user":     ReturnURI(ctx, "other", "secret", "100.64.0.1", "6033", "pf_cache_a"),
		"password": ReturnURI(ctx, "pf", "rotated", "100.64.0.1", "6033", "pf_cache_a"),
		"host":     ReturnURI(ctx, "pf", "secret", "100.64.0.2", "6033", "pf_cache_a"),
	} {
		other, err := cachedConnectURI(ctx, uri)
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		if other == base {
			t.Errorf("different %s shared a pool", name)
		}
	}
}

// ConnectURI and ManualConnectDb hand out pools the caller owns and may Close
// (galeraautofix does), so they must never come from the cache.
func TestUncachedConstructorsReturnFreshPools(t *testing.T) {
	ctx := context.Background()
	uri := ReturnURI(ctx, "pf", "secret", "100.64.0.1", "6033", "pf_cache_uncached")
	cached, err := cachedConnectURI(ctx, uri)
	if err != nil {
		t.Fatal(err)
	}

	a, err := ConnectURI(ctx, uri)
	if err != nil {
		t.Fatal(err)
	}
	defer a.Close()
	b, err := ConnectURI(ctx, uri)
	if err != nil {
		t.Fatal(err)
	}
	defer b.Close()
	if a == b || a == cached || b == cached {
		t.Fatal("ConnectURI returned a shared pool")
	}

	m, err := ManualConnectDb(ctx, "pf", "secret", "100.64.0.1", "6033", "pf_cache_uncached")
	if err != nil {
		t.Fatal(err)
	}
	defer m.Close()
	if m == cached {
		t.Fatal("ManualConnectDb returned the cached pool")
	}
}

func TestCachedConnectURIConcurrent(t *testing.T) {
	ctx := context.Background()
	uri := ReturnURI(ctx, "pf", "secret", "100.64.0.1", "6033", "pf_cache_concurrent")

	const n = 100
	results := make([]any, n)
	var wg sync.WaitGroup
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			db, err := cachedConnectURI(ctx, uri)
			if err != nil {
				t.Error(err)
				return
			}
			results[i] = db
		}(i)
	}
	wg.Wait()
	for i := 1; i < n; i++ {
		if results[i] != results[0] {
			t.Fatalf("goroutine %d got a different pool", i)
		}
	}
}

// A DSN that fails to parse is a hard error: it is returned, never cached, and
// does not poison later lookups.
func TestCachedConnectURIDoesNotCacheErrors(t *testing.T) {
	ctx := context.Background()
	bad := "user@tcp(bad"

	if db, err := cachedConnectURI(ctx, bad); err == nil {
		t.Fatalf("malformed DSN opened a pool: %v", db)
	} else if !errors.Is(err, ErrInvalidConfig) {
		t.Fatalf("malformed DSN error is not ErrInvalidConfig: %v", err)
	}
	poolCache.mu.Lock()
	_, cached := poolCache.pools[bad]
	poolCache.mu.Unlock()
	if cached {
		t.Fatal("malformed DSN was cached")
	}
	if _, err := cachedConnectURI(ctx, bad); err == nil {
		t.Fatal("second open of malformed DSN succeeded")
	}

	good := ReturnURI(ctx, "pf", "secret", "100.64.0.1", "6033", "pf_cache_after_error")
	if _, err := cachedConnectURI(ctx, good); err != nil {
		t.Fatalf("valid DSN after an error: %v", err)
	}
}
