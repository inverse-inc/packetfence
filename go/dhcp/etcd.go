package main

import (
	"context"
	"time"

	"github.com/coreos/etcd/client"
)

// etcdInit initiate the connection to etcd
func etcdInit() *client.Config {
	cfg := client.Config{
		Endpoints: []string{"http://127.0.0.1:2379"},
		Transport: client.DefaultTransport,
		// set timeout per request to fail fast when the target endpoint is unavailable
		HeaderTimeoutPerRequest: time.Second,
	}
	return &cfg
}

func etcdInsert(key string, value string) bool {
	c, err := client.New(*Capi)
	if err != nil {
		return false
	}
	kapi := client.NewKeysAPI(c)
	_, err = kapi.Set(context.Background(), "/dhcpd/"+key, value, nil)
	if err != nil {
		return false
	} else {
		return true
	}
}

func etcdGet(key string) (string, string) {
	c, err := client.New(*Capi)
	if err != nil {
		return "", ""
	}
	kapi := client.NewKeysAPI(c)
	resp, err := kapi.Get(context.Background(), "/dhcpd/"+key, nil)
	if err != nil {
		return "", ""
	}
	return resp.Node.Key, resp.Node.Value
}

func etcdDel(key string) bool {
	c, err := client.New(*Capi)
	if err != nil {
		return false
	}
	kapi := client.NewKeysAPI(c)
	_, err = kapi.Delete(context.Background(), "/dhcpd/"+key, nil)
	if err != nil {
		return false
	}
	return true
}
