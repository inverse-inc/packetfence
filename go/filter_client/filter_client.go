package filter_client

import (
    "bufio"
    "encoding/json"
    "net"
    "fmt"
)

type Request struct {
    Method string `json:"method"`
    Params interface{} `json:"params"`
}

type ClientError struct {
    Code int `json:"code"`
    Message string `json:message`
    Data interface{} `json:data`
}

type Response struct {
    Result *interface{} `json:"result"`
    Error *ClientError `json:"error"`
}

type Client struct {
    SocketPath string
}


func (c *Client) FilterProfile(data interface{}) (interface{}, error) {
    socket, err := net.Dial("unix", c.SocketPath)
    if (err != nil) {
        return nil, err
    }
    defer socket.Close()
    return c.SendResponse("filter_profile", data, socket)
}

func (c *Client) accessFilter(filter string, scope string, data interface{}) (interface{}, error) {
    socket, err := net.Dial("unix", c.SocketPath)
    if (err != nil) {
        return nil, err
    }
    defer socket.Close()
    return c.SendResponse(filter, []interface{}{scope, data}, socket)
}

func (c *Client) FilterVlan(scope string, data interface{}) (interface{}, error) {
    return c.accessFilter("filter_vlan", scope, data)
}

func (c *Client) FilterDhcp(scope string, data interface{}) (interface{}, error) {
    return c.accessFilter("filter_dhcp", scope, data)
}

func (c *Client) FilterDns(scope string, data interface{}) (interface{}, error) {
    return c.accessFilter("filter_dns", scope, data)
}

func (c *Client) FilterRadius(scope string, data interface{}) (interface{}, error) {
    return c.accessFilter("filter_radius", scope, data)
}

func (c *Client) SendResponse(method string, params interface{}, conn net.Conn) (interface{}, error) {
    request := Request{Method:method, Params: params}
    b, err := json.Marshal(request)
    if (err != nil) {
        return nil, err
    }
    b = append(b,'\n')
    _, err = conn.Write(b);
    if (err != nil) {
        return nil, err
    }
    reader := bufio.NewReader(conn)
    b2, err := reader.ReadBytes('\n')
    if (err != nil) {
        return nil, err
    }
    var response Response
    err = json.Unmarshal(b2, &response);
    if (err != nil) {
        return nil, err
    }
    if response.Error != nil {
        return nil, fmt.Errorf("%s", response.Error.Message );
    }

    if response.Result == nil {
        return nil, fmt.Errorf("No valid result returned")
    }

    return *response.Result, nil
}
