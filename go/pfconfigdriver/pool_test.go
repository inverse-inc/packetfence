package pfconfigdriver

import (
	"context"
	"testing"
	"time"
)

type refreshableStruct struct {
	refreshedAt time.Time
}

func (rs *refreshableStruct) Refresh(ctx context.Context) {
	rs.refreshedAt = time.Now()
}

func TestPoolRefreshables(t *testing.T) {
	p := NewPool()
	rs := &refreshableStruct{}
	p.AddRefreshable(ctx, rs)

	now := time.Now()

	if now.Before(rs.refreshedAt) {
		t.Error("Struct has already been refreshed although it shouldn't have")
	}

	if p.refreshables[0] != rs {
		t.Error("Added refreshable wasn't added properly")
	}

	p.refreshRefreshables(ctx)

	if now.After(rs.refreshedAt) {
		t.Error("Struct hasn't been refreshed properly")
	}
}

func TestPoolStructs(t *testing.T) {
	p := NewPool()
	config := &configStruct{}
	p.AddStruct(ctx, config)

	p.refreshStructs(ctx)

	if config.PfConf.General.Domain != "pfdemo.org" {
		t.Error("Struct hasn't been refreshed properly")
	}

	// Add it again and make sure its only there once
	p.AddStruct(ctx, config)

	if len(p.structs) > 1 {
		t.Error("Same struct to refresh was added twice instead of only once")
	}
}
