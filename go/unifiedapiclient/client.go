package unifiedapiclient

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/davecgh/go-spew/spew"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

const (
	API_LOGIN_PATH = "/api/v1/login"
)

var httpClient *http.Client

func dialTimeout(network, addr string) (net.Conn, error) {
	return net.DialTimeout(network, addr, 1*time.Second)
}

func init() {
	tr := &http.Transport{
		TLSClientConfig:     &tls.Config{InsecureSkipVerify: true},
		TLSHandshakeTimeout: 1 * time.Second,
		Dial:                dialTimeout,
	}
	httpClient = &http.Client{
		Transport: tr,
	}
}

func SetHTTPClient(hc *http.Client) {
	httpClient = hc
}

const UnsetTenantId = -1

type Client struct {
	Username string
	Password string
	Host     string
	Port     string
	token    string
	tenantId int

	// When set to true, the URI log will be made in debug instead of info
	URILogDebug bool
}

type DummyReply struct{}

type LoginReply struct {
	Token string `json:"token"`
}

type UnifiedAPIError interface {
	Error() string
	StatusCode() int
}

type ErrorReply struct {
	Message string `json:"message"`
	Status  int    `json:"status"`
}

func (er *ErrorReply) Error() string {
	return er.Message
}

func (er *ErrorReply) StatusCode() int {
	return er.Status
}

func NewErrorReply(status int, msg string) *ErrorReply {
	return &ErrorReply{Message: msg, Status: status}
}

func New(ctx context.Context, username, password, proto, host, port string) *Client {
	return &Client{
		Username: username,
		Password: password,
		Host:     host,
		Port:     port,
		tenantId: UnsetTenantId,
	}
}

func NewFromConfig(ctx context.Context) *Client {
	var webservices pfconfigdriver.PfConfWebservices
	pfconfigdriver.FetchDecodeSocket(ctx, &webservices)

	var apiUser pfconfigdriver.UnifiedApiSystemUser
	pfconfigdriver.FetchDecodeSocket(ctx, &apiUser)

	return New(ctx, apiUser.User, apiUser.Pass, webservices.Proto, webservices.Host, webservices.UnifiedAPIPort)
}

func (c *Client) Call(ctx context.Context, method, path string, decodeResponseIn interface{}) UnifiedAPIError {
	return c.CallWithStringBody(ctx, method, path, "", decodeResponseIn)
}

func (c *Client) CallWithBody(ctx context.Context, method, path string, payload interface{}, decodeResponseIn interface{}) UnifiedAPIError {
	data, err := json.Marshal(payload)
	sharedutils.CheckError(err)
	return c.CallWithStringBody(ctx, method, path, string(data), decodeResponseIn)
}

func (c *Client) CallWithStringBody(ctx context.Context, method, path, body string, decodeResponseIn interface{}) UnifiedAPIError {
	r := c.buildRequest(ctx, method, path, body)
	resp, err := httpClient.Do(r)
	defer c.ensureRequestComplete(ctx, resp)

	if err != nil {
		return NewErrorReply(0, err.Error())
	}

	// Lower than 400 is a success
	if resp.StatusCode < 400 {
		dec := json.NewDecoder(resp.Body)
		err := dec.Decode(decodeResponseIn)
		if err != nil {
			return NewErrorReply(0, err.Error())
		} else {
			return nil
		}

		// If we got a 401 and aren't currently logging in then we try to login and retry the request
	} else if resp.StatusCode == http.StatusUnauthorized && path != API_LOGIN_PATH {
		log.LoggerWContext(ctx).Info("Request isn't authorized, performing login against the Unified API")
		err := c.login(ctx)

		if err != nil {
			spew.Dump(err)
			return NewErrorReply(resp.StatusCode, err.Error())
		}

		return c.CallWithStringBody(ctx, method, path, body, decodeResponseIn)
	} else {
		errRep := &ErrorReply{Status: resp.StatusCode}
		dec := json.NewDecoder(resp.Body)
		err := dec.Decode(&errRep)

		if err != nil {
			return NewErrorReply(resp.StatusCode, "Error body doesn't follow the Unified API standard, couldn't extract the error message from it.")
		}

		return errRep
	}
}

func (c *Client) CallSimpleHtml(ctx context.Context, method, path, body string) ([]byte, error) {
	r := c.buildRequest(ctx, method, path, body)
	resp, err := httpClient.Do(r)
	defer c.ensureRequestComplete(ctx, resp)

	if err != nil {
		return []byte{}, err
	}

	// Lower than 400 is a success
	if resp.StatusCode < 400 {
		res, err := ioutil.ReadAll(resp.Body)
		return res, err

		// If we got a 401 and aren't currently logging in then we try to login and retry the request
	} else if resp.StatusCode == http.StatusUnauthorized && path != API_LOGIN_PATH {
		log.LoggerWContext(ctx).Info("Request isn't authorized, performing login against the Unified API")
		err := c.login(ctx)

		if err != nil {
			return []byte{}, err
		}

		return c.CallSimpleHtml(ctx, method, path, body)
	} else {
		errRep := &ErrorReply{}
		dec := json.NewDecoder(resp.Body)
		err := dec.Decode(&errRep)

		if err != nil {
			return []byte{}, errors.New("Error body doesn't follow the Unified API standard, couldn't extract the error message from it.")
		}

		return []byte{}, errors.New(errRep.Message)
	}
}

// Ensures that the full body is read and closes the reader so that the connection can be reused
func (c *Client) ensureRequestComplete(ctx context.Context, resp *http.Response) {
	if resp == nil {
		return
	}

	defer resp.Body.Close()
	io.Copy(ioutil.Discard, resp.Body)
}

func (c *Client) login(ctx context.Context) UnifiedAPIError {
	loginBody := map[string]string{
		"username": c.Username,
		"password": c.Password,
	}

	loginBodyBytes, err := json.Marshal(loginBody)
	sharedutils.CheckError(err)

	reply := LoginReply{}

	errRep := c.CallWithStringBody(ctx, "POST", API_LOGIN_PATH, string(loginBodyBytes), &reply)
	if errRep != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error while performing a login on the UnifiedAPI: %s", err))
		return errRep
	}

	c.token = reply.Token

	return nil
}

func (c *Client) buildRequest(ctx context.Context, method, path, body string) *http.Request {
	uri := fmt.Sprintf("https://%s:%s%s", c.Host, c.Port, path)

	logFunc := log.LoggerWContext(ctx).Info
	if c.URILogDebug {
		logFunc = log.LoggerWContext(ctx).Debug
	}
	logFunc("Calling Unified API on uri: " + uri)

	bodyReader := strings.NewReader("")
	if body != "" {
		bodyReader = strings.NewReader(body)
	}

	r, err := http.NewRequest(method, uri, bodyReader)
	sharedutils.CheckError(err)

	if c.token != "" {
		r.Header.Set("Authorization", "Bearer "+c.token)
	}

	if c.tenantId != UnsetTenantId {
		r.Header.Set("X-PacketFence-Tenant-Id", fmt.Sprintf("%d", c.tenantId))
	}

	return r
}

func (c *Client) SetTenantId(ctx context.Context, tenantId int) {
	c.tenantId = tenantId
}

func (c *Client) ResetTenantId(ctx context.Context) {
	c.tenantId = UnsetTenantId
}

func (c *Client) GetToken(ctx context.Context) string {
	return c.token
}
