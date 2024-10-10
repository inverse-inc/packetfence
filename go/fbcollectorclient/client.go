package fbcollectorclient

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
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

	URILogDebug bool
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

func (c *Client) Call(ctx context.Context, method, path string, payload, decodeResponseIn interface{}) error {
	var data []byte = nil
	var err error
	if payload != nil {
		data, err = json.Marshal(payload)
		if err != nil {
			return fmt.Errorf("Unable to encode request payload: %s", err)
		}
	}

	r := c.buildRequest(ctx, method, path, data)
	resp, err := c.httpClient.Do(r)
	if err != nil {
		return err
	}

	defer c.ensureRequestComplete(ctx, resp)
	if resp.StatusCode < 400 {
		dec := json.NewDecoder(resp.Body)
		err := dec.Decode(decodeResponseIn)
		if err != nil {
			return fmt.Errorf("Unable to decode JSON response: %s", err)
		}

		return nil
	}

	errRep := struct {
		Error string
	}{}
	err = json.NewDecoder(resp.Body).Decode(&errRep)

	if err != nil {
		return fmt.Errorf("Error body doesn't follow the standard, couldn't extract the error message from it. Status code was %d", resp.StatusCode)
	}

	return fmt.Errorf("Error while querying collector: %s", errRep.Error)
}

func (c *Client) buildRequest(ctx context.Context, method, path string, body []byte) *http.Request {
	uri := fmt.Sprintf("%s://%s:%s%s", c.Proto, c.Host, c.Port, path)

	logFunc := log.LoggerWContext(ctx).Info
	if c.URILogDebug {
		logFunc = log.LoggerWContext(ctx).Debug
	}
	logFunc("Calling collector API on uri: " + uri)

	bodyReader := bytes.NewReader(body)

	r, err := http.NewRequest(method, uri, bodyReader)
	sharedutils.CheckError(err)

	if c.key != "" {
		r.Header.Set("Authorization", "Token "+c.key)
	}

	return r
}

func (c *Client) ensureRequestComplete(ctx context.Context, resp *http.Response) {
	if resp == nil {
		return
	}

	defer resp.Body.Close()
	io.Copy(ioutil.Discard, resp.Body)
}

type ClientFromConfig struct {
	Client
	conf pfconfigdriver.FingerbankSettings
}

var DefaultClient = FromConfig(context.Background())

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

func (c *ClientFromConfig) IsValid(ctx context.Context) bool {
	return pfconfigdriver.IsValid(ctx, &c.conf)
}

func (c *ClientFromConfig) Clone() pfconfigdriver.Refresh {
	clone := &ClientFromConfig{
		conf: c.conf,
	}

	clone.Client = clone.buildFromConf(context.Background())
	return clone
}
