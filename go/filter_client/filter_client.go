package filter_client

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
)

const defaultSocketPath string = "/usr/local/pf/var/run/pffilter.sock"

// Represents the json message to send to the pffilter service
type Request struct {
	Method string      `json:"method"`
	Params interface{} `json:"params"`
}

// Represents the json error received from the pffilter service
type ClientError struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data"`
}

// Represents the json repsonse received from the pffilter service
type Response struct {
	Result *interface{} `json:"result"`
	Error  *ClientError `json:"error"`
}

// The Client struct
type Client struct {
	SocketPath string
}

// The Client constructor
func NewClient() Client {
	return NewClientWithPath(defaultSocketPath)
}

// The Client constructor with a path
func NewClientWithPath(path string) Client {
	return Client{SocketPath: path}
}

// Sends a filter_profile message to the pffilter service
func (c *Client) FilterProfile(data interface{}) (interface{}, error) {
	socket, err := net.Dial("unix", c.SocketPath)
	if err != nil {
		return nil, err
	}
	defer socket.Close()
	return c.SendRequest("filter_profile", data, socket)
}

// A generalize function for sending access filter messages
func (c *Client) AccessFilter(filter string, scope string, data interface{}) (interface{}, error) {
	socket, err := net.Dial("unix", c.SocketPath)
	if err != nil {
		return nil, err
	}
	defer socket.Close()
	return c.SendRequest(filter, []interface{}{scope, data}, socket)
}

// Sends a filter_vlan message to the pffilter service
func (c *Client) FilterVlan(scope string, data interface{}) (interface{}, error) {
	return c.AccessFilter("filter_vlan", scope, data)
}

// Sends a filter_dhcp message to the pffilter service
func (c *Client) FilterDhcp(scope string, data interface{}) (interface{}, error) {
	return c.AccessFilter("filter_dhcp", scope, data)
}

// Sends a filter_dns message to the pffilter service
func (c *Client) FilterDns(scope string, data interface{}) (interface{}, error) {
	return c.AccessFilter("filter_dns", scope, data)
}

// Sends a filter_radius message to the pffilter service
func (c *Client) FilterRadius(scope string, data interface{}) (interface{}, error) {
	return c.AccessFilter("filter_radius", scope, data)
}

// Sends a filter_remote_profile message to the pffilter service
func (c *Client) FilterRemoteProfile(scope string, data interface{}) (interface{}, error) {
	return c.AccessFilter("filter_remote_profile", scope, data)
}

// Send a request to the pffilter service
func (c *Client) SendRequest(method string, params interface{}, conn net.Conn) (interface{}, error) {
	request := Request{Method: method, Params: params}
	b, err := json.Marshal(request)
	if err != nil {
		return nil, err
	}
	b = append(b, '\n')
	_, err = conn.Write(b)
	if err != nil {
		return nil, err
	}
	reader := bufio.NewReader(conn)
	b2, err := reader.ReadBytes('\n')
	if err != nil {
		return nil, err
	}
	var response Response
	err = json.Unmarshal(b2, &response)
	if err != nil {
		return nil, err
	}
	if response.Error != nil {
		return nil, fmt.Errorf("%s", response.Error.Message)
	}

	if response.Result == nil {
		return nil, fmt.Errorf("No valid result returned")
	}

	return *response.Result, nil
}
