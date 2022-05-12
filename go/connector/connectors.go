package connector

import (
	"context"
	"net"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// A struct which contains all the connector IDs along with their instantiated Connectors struct
// It implements pfconfigdriver.Refreshable so that this can be part of a pfconfigdriver.Pool
type ConnectorsContainer struct {
	pfconfigdriver.CachedHash
	factory Factory
}

func NewConnectorsContainer(ctx context.Context) *ConnectorsContainer {
	cc := &ConnectorsContainer{}
	cc.PfconfigNS = "config::Connector"
	cc.factory = NewFactory(ctx)
	cc.New = func(ctx context.Context, id string) (pfconfigdriver.PfconfigObject, error) {
		return cc.factory.Instantiate(ctx, id)
	}
	cc.Refresh(ctx)
	return cc
}

func (cc *ConnectorsContainer) All(ctx context.Context) map[string]*Connector {
	connectors := map[string]*Connector{}
	for id, o := range cc.Structs {
		connectors[id] = o.(*Connector)
	}
	return connectors
}

func (cc *ConnectorsContainer) Get(ctx context.Context, id string) *Connector {
	return cc.Structs[id].(*Connector)
}

func (cc *ConnectorsContainer) ForIP(ctx context.Context, ip net.IP) *Connector {
	for _, id := range cc.Keys(ctx) {
		c := cc.Get(ctx, id)
		for _, network := range c.NetworksObjects {
			if network.Contains(ip) {
				return c
			}
		}
	}
	return cc.Get(ctx, "local_connector")
}

const connectorsContainerContextKey = "ConnectorsContainerContextKey"

func ConnectorsContainerFromContext(ctx context.Context) *ConnectorsContainer {
	if o := ctx.Value(connectorsContainerContextKey); o != nil {
		return o.(*ConnectorsContainer)
	} else {
		return nil
	}
}

func WithConnectorsContainer(ctx context.Context, cc *ConnectorsContainer) context.Context {
	return context.WithValue(ctx, connectorsContainerContextKey, cc)
}
