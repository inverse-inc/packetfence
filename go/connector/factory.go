package connector

import (
	"context"

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
	c := Connector{}
	c.PfconfigHashNS = id
	_, err := pfconfigdriver.FetchDecodeSocketCache(ctx, &c)
	if err != nil {
		return nil, err
	}
	err = c.init()
	return &c, err
}
