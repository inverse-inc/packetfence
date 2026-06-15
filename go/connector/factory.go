package connector

import (
	"context"
	"fmt"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// A factory for Connector
type Factory struct {
}

// Create a new Connector factory containing all the valid types
func NewFactory(ctx context.Context) Factory {
	f := Factory{}
	return f
}

// Instantiate a new Connector given its configuration ID in PacketFence
func (f *Factory) Instantiate(ctx context.Context, id string) (*Connector, error) {
	// An empty id would set PfconfigHashNS to "" which, combined with the
	// `val:"-"` tag on the field, makes pfconfigdriver panic ("user specified
	// value is required"). A stray/empty section in connectors.conf is enough
	// to surface an empty key here, so guard against it instead of letting the
	// panic tear down the HTTP serving goroutine. CachedHash.Refresh logs and
	// skips instantiation errors.
	if id == "" {
		return nil, fmt.Errorf("cannot instantiate connector with an empty id")
	}
	c := Connector{}
	c.PfconfigHashNS = id
	_, err := pfconfigdriver.FetchDecodeSocketCache(ctx, &c)
	if err != nil {
		return nil, err
	}
	err = c.init()
	return &c, err
}
