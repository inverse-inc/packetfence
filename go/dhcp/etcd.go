package main

import (
	"context"
	"time"

	"github.com/coreos/etcd/client"
	"github.com/inverse-inc/packetfence/go/log"
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
		log.LoggerWContext(ctx).Error("Error while creating etcd client: " + err.Error())
		return false
	}
	kapi := client.NewKeysAPI(c)
	_, err = kapi.Set(context.Background(), "/dhcpd/"+key, value, nil)
	if err != nil {
		log.LoggerWContext(ctx).Error("Error while inserting into etcd: " + err.Error())
		return false
	} else {
		return true
	}
}

func etcdGet(key string) (string, string) {
	c, err := client.New(*Capi)
	if err != nil {
		log.LoggerWContext(ctx).Error("Error while creating etcd client: " + err.Error())
		return "", ""
	}
	kapi := client.NewKeysAPI(c)
	resp, err := kapi.Get(context.Background(), "/dhcpd/"+key, nil)
	if err != nil {
		log.LoggerWContext(ctx).Debug("Error while getting etcd key '" + key + "': " + err.Error())
		return "", ""
	}
	return resp.Node.Key, resp.Node.Value
}

func etcdDel(key string) bool {
	c, err := client.New(*Capi)
	if err != nil {
		log.LoggerWContext(ctx).Error("Error while creating etcd client: " + err.Error())
		return false
	}
	kapi := client.NewKeysAPI(c)
	_, err = kapi.Delete(context.Background(), "/dhcpd/"+key, nil)
	if err != nil {
		log.LoggerWContext(ctx).Error("Error while deleting etcd key '" + key + "': " + err.Error())
		return false
	}
	return true
}
