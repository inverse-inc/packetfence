package uiplugins

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/alicebob/miniredis/v2"
	"github.com/redis/go-redis/v9"
)

func TestRegistry(t *testing.T) {
	ctx := context.Background()
	mr := miniredis.RunT(t)
	expired := []string{}
	reg := &Registry{
		Redis:  redis.NewClient(&redis.Options{Addr: mr.Addr()}),
		Expire: func(ctx context.Context, ns string) error { expired = append(expired, ns); return nil },
	}

	r := Registration{ID: "acme", Host: "acme", Port: 8080, ManifestPath: "/pf-ui/manifest.json"}
	if err := reg.Register(ctx, r); err != nil {
		t.Fatal(err)
	}
	stored := Registration{}
	if err := json.Unmarshal([]byte(mr.HGet(RedisKey, "acme")), &stored); err != nil {
		t.Fatal(err)
	}
	if stored.Scheme != "http" || stored.Port != 8080 || stored.ManifestURL() != "http://acme:8080/pf-ui/manifest.json" {
		t.Errorf("unexpected registration %+v", stored)
	}
	if len(expired) != 1 || expired[0] != Namespace {
		t.Errorf("namespace not expired after register: %v", expired)
	}

	for _, bad := range []Registration{
		{ID: "Acme", Host: "acme", Port: 1, ManifestPath: "/m"},
		{ID: "acme", Host: "", Port: 1, ManifestPath: "/m"},
		{ID: "acme", Host: "acme", Port: 70000, ManifestPath: "/m"},
		{ID: "acme", Host: "acme", Port: 1, ManifestPath: "m"},
		{ID: "acme", Scheme: "ftp", Host: "acme", Port: 1, ManifestPath: "/m"},
	} {
		if err := reg.Register(ctx, bad); err == nil {
			t.Errorf("invalid registration accepted: %+v", bad)
		}
	}

	if err := reg.Deregister(ctx, "acme"); err != nil {
		t.Fatal(err)
	}
	if mr.HGet(RedisKey, "acme") != "" {
		t.Error("registration not removed")
	}
	if len(expired) != 2 {
		t.Errorf("namespace not expired after deregister: %v", expired)
	}
}
