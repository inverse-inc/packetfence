package connector

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/url"

	"github.com/davecgh/go-spew/spew"
	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

type Connector struct {
	pfconfigdriver.StructConfig
	PfconfigMethod  string   `val:"hash_element"`
	PfconfigNS      string   `val:"config::Connector"`
	PfconfigHashNS  string   `val:"-"`
	Secret          string   `json:"secret"`
	Networks        []string `json:"networks"`
	NetworksObjects []*net.IPNet
}

type DynReverseConnectionInfo struct {
	Message string      `json:"message"`
	Host    string      `json:"host"`
	Port    json.Number `json:"port"`
}

func (c *Connector) init() error {
	for _, network := range c.Networks {
		_, ipnet, err := net.ParseCIDR(network)
		if err != nil {
			return fmt.Errorf("Unable to parse network %s: %s", network, err)
		}
		c.NetworksObjects = append(c.NetworksObjects, ipnet)
	}
	return nil
}

func (c *Connector) connectorServerApiClient(ctx context.Context) (*unifiedapiclient.Client, error) {
	res := redisClient.Get(fmt.Sprintf("%s%s", redisTunnelsNamespace, c.PfconfigHashNS))
	client := unifiedapiclient.NewFromConfig(ctx)
	if s, err := res.Result(); err != nil && err != redis.Nil {
		err := fmt.Errorf("Unable to find active tunnel %s via Redis: %s", c.PfconfigHashNS, err)
		log.LoggerWContext(ctx).Error(err.Error())
		return nil, err
	} else if err == redis.Nil {
		return client, nil
	} else {
		u, err := url.Parse(s)
		if err != nil {
			err := fmt.Errorf("Unable to parse active tunnel URL '%s' for %s: %s", s, c.PfconfigHashNS, err)
			log.LoggerWContext(ctx).Error(err.Error())
			return nil, err
		}
		client.Proto = u.Scheme
		client.Host = u.Hostname()
		client.Port = u.Port()
		return client, nil
	}
}

func (c *Connector) DynReverse(ctx context.Context, to string) (DynReverseConnectionInfo, error) {
	client, err := c.connectorServerApiClient(ctx)
	if err != nil {
		return DynReverseConnectionInfo{}, err
	}
	resp := DynReverseConnectionInfo{}
	err = client.CallWithBody(ctx, "GET", "/api/v1/pfconnector/dynreverse",
		gin.H{"to": to, "connector_id": c.PfconfigHashNS},
		&resp,
	)
	spew.Dump(resp)
	return resp, err
}
