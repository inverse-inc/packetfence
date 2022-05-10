package fbcollectorclient

import (
	"context"
	"crypto/tls"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func dialTimeout(network, addr string) (net.Conn, error) {
	return net.DialTimeout(network, addr, 1*time.Second)
}

func init() {
}

type Client struct {
	httpClient *http.Client
	Proto      string
	Host       string
	Port       string
	key        string
}

func ProxyURL(ctx context.Context, conf pfconfigdriver.FingerbankSettingsProxy) *url.URL {
	if sharedutils.IsEnabled(conf.UseProxy) {
		u, err := url.Parse(fmt.Sprintf("http://%s:%s", conf.Host, conf.Port))
		if err != nil {
			log.LoggerWContext(ctx).Error("Unable to create Fingerbank proxy URL from configuration: %s", err)
			return nil
		}
		return u
	} else {
		return nil
	}
}

func New(ctx context.Context, key, proto, host, port string, proxy *url.URL) *Client {
	tr := &http.Transport{
		TLSClientConfig:     &tls.Config{InsecureSkipVerify: true},
		TLSHandshakeTimeout: 1 * time.Second,
		Dial:                dialTimeout,
	}

	if proxy != nil {
		tr.Proxy = http.ProxyURL(proxy)
	}

	httpClient := &http.Client{
		Transport: tr,
	}

	return &Client{
		key:        key,
		Proto:      proto,
		Host:       host,
		Port:       port,
		httpClient: httpClient,
	}
}

type ClientFromConfig struct {
	Client
	conf pfconfigdriver.FingerbankSettings
}

func FromConfig(ctx context.Context) *ClientFromConfig {
	conf := pfconfigdriver.FingerbankSettings{}
	pfconfigdriver.FetchDecodeSocketCache(ctx, &conf)

	c := &ClientFromConfig{
		conf: conf,
	}
	c.Client = c.buildFromConf(ctx)

	return c
}

func (c *ClientFromConfig) buildFromConf(ctx context.Context) Client {
	proto := "http"
	if sharedutils.IsEnabled(c.conf.Collector.UseHttps) {
		proto = "https"
	}
	return *(New(
		ctx,
		c.conf.Upstream.ApiKey,
		proto,
		c.conf.Collector.Host,
		c.conf.Collector.Port.String(),
		ProxyURL(ctx, c.conf.Proxy),
	))
}

func (c *ClientFromConfig) Refresh(ctx context.Context) {
	if !pfconfigdriver.IsValid(ctx, &c.conf) {
		pfconfigdriver.FetchDecodeSocketCache(ctx, &c.conf)
		c.Client = c.buildFromConf(ctx)
	}
}
