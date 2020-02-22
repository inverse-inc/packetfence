package jsonrpc2

import (
	"context"
    "io/ioutil"
    "bytes"
    "net"
	"time"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"net/http"
)

var httpClient *http.Client = &http.Client{
	Transport: &http.Transport{
		TLSClientConfig:     &tls.Config{InsecureSkipVerify: true},
		TLSHandshakeTimeout: 1 * time.Second,
		Dial:                dialTimeout,
	},
}

func dialTimeout(network, addr string) (net.Conn, error) {
	return net.DialTimeout(network, addr, 1*time.Second)
}

type Client struct {
	Id       uint
	Username string
	Password string
	Proto    string
	Host     string
	Port     string
	Method   string
}

type JsonRPC2Request struct {
	Method   string      `json:"method"`
	JsonRPC  string      `json:"jsonrpc"`
	Params   interface{} `json:"params"`
	TenantId int         `json:"tenant_id"`
	Id       uint        `json:"id,omitempty"`
}

type JsonRPC2Error struct {
    Code int `json:"code"`
    Message string `json:"message"`
    Data    interface{} `json:"data,omitempty"`
}

func (e *JsonRPC2Error) Error() string {
    return e.Message
}

type JsonRPC2Response struct {
	JsonRPC  string      `json:"jsonrpc"`
    Result   interface{} `json:"result,omitempty"`
    Error    *JsonRPC2Error `json:"error,omitempty"`
	Id       uint        `json:"id"`
}

func NewClientFromConfig(ctx context.Context) *Client {
	var webservices pfconfigdriver.PfConfWebservices
	pfconfigdriver.FetchDecodeSocket(ctx, &webservices)
	return &Client{
		Username: webservices.User,
		Password: webservices.Pass,
		Proto:    webservices.Proto,
		Host:     webservices.Host,
		Port:     webservices.Port,
	}
}

func NewAAAClientFromConfig(ctx context.Context) *Client {
	var webservices pfconfigdriver.PfConfWebservices
	var ports pfconfigdriver.PfConfPorts
	pfconfigdriver.FetchDecodeSocket(ctx, &webservices)
	pfconfigdriver.FetchDecodeSocket(ctx, &ports)
	return &Client{
		Username: webservices.User,
		Password: webservices.Pass,
		Proto:    webservices.Proto,
		Host:     webservices.Host,
		Port:     ports.AAA,
	}
}

func (c *Client) Call(method string, args interface{}, tenant_id int) (interface{}, error) {
	c.Id++
	request := JsonRPC2Request{
		Method:   method,
		JsonRPC:  "2.0",
		Params:   args,
		TenantId: tenant_id,
		Id:       c.Id,
	}

    r, err := c.buildRequest(&request)
    if err != nil {
        return nil, err
    }

	resp, err := httpClient.Do(r)
    if err != nil {
        return nil, err
    }

    
    body, err := ioutil.ReadAll(resp.Body)
    resp.Body.Close()
    var response JsonRPC2Response
    err = json.Unmarshal(body, &response)
    if err != nil {
        return nil, err
    }

    if response.Error != nil {
        return nil, response.Error
    }

	return response.Result, nil
}

func (c *Client) Notify(method string, args interface{}, tenant_id int) error {
	request := JsonRPC2Request{
		Method:   method,
		JsonRPC:  "2.0",
		Params:   args,
		TenantId: tenant_id,
		Id:       0,
	}

    r, err := c.buildRequest(&request)
    if err != nil {
        return err
    }

	resp, err := httpClient.Do(r)
    if err != nil {
        return err
    }

    _, err = ioutil.ReadAll(resp.Body)
    resp.Body.Close()
    return nil
}

func (c *Client) buildRequest(jr *JsonRPC2Request) (*http.Request, error) {
	uri := fmt.Sprintf("%s://%s:%s", c.Proto, c.Host, c.Port)
	var data []byte
    var err error
	if data, err = json.Marshal(jr); err != nil {
		return nil, err
	}

	r, err := http.NewRequest("POST", uri, bytes.NewReader(data))
	if err != nil {
		return nil, err
	}

	r.Header.Set("Content-Type", "application/json-rpc")
	r.Header.Set("Request", jr.Method)
	if c.Proto == "https" {
		r.SetBasicAuth(c.Username, c.Password)
	}

	return r, nil
}
