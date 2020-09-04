package remoteclients

import (
	"context"
	"net"
	"time"

	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
	"github.com/jcuga/golongpoll"
	"github.com/jinzhu/gorm"
)

// TODO: have this configurable and potentially support multiple ranges
var startingIP = sharedutils.IP2Int(net.ParseIP("192.168.69.1"))
var netmask = 24

var PublishNewClientsTo *golongpoll.LongpollManager

type RemoteClient struct {
	ID        uint `gorm:"primary_key"`
	CreatedAt time.Time
	UpdatedAt time.Time
	TenantId  uint
	PublicKey string
	MAC       string
}

func GetOrCreateRemoteClient(ctx context.Context, db *gorm.DB, publicKey string, mac string, categoryId uint) (*RemoteClient, error) {
	rc := RemoteClient{MAC: mac}
	rcn := rc.GetNode(ctx)

	categoryIdChanged := categoryId != rcn.CategoryId

	rcn.MAC = mac
	rcn.CategoryId = categoryId
	rc.UpsertNode(ctx, rcn)

	db.Where("public_key = ?", publicKey).First(&rc)
	if rc.PublicKey != publicKey {
		rc.PublicKey = publicKey
		log.LoggerWContext(ctx).Info("Client " + rc.PublicKey + " has just been created. Publishing its presence.")
		err := db.Create(&rc).Error
		publishNewClient(ctx, db, rc)
		return &rc, err
	} else {
		if categoryIdChanged {
			log.LoggerWContext(ctx).Info("Client " + rc.PublicKey + " has changed role. Publishing its presence.")
			db.Save(&rc)
			publishNewClient(ctx, db, rc)
		}

		return &rc, nil
	}
}

func publishNewClient(ctx context.Context, db *gorm.DB, rc RemoteClient) {
	if PublishNewClientsTo != nil {
		rcs := []RemoteClient{}
		peers := rc.AllowedPeers(ctx, db)
		if err := db.Where("public_key IN (?)", peers).Find(&rcs).Error; err != nil {
			// TODO: handle this differently like with retries
			panic("Failed to get clients to publish new peer")
		}
		for _, publishTo := range rcs {
			log.LoggerWContext(ctx).Info("Publishing new peer to " + publishTo.PublicKey)
			PublishNewClientsTo.Publish(PRIVATE_EVENTS_SUFFIX+publishTo.PublicKey, Event{
				Type: "new_peer",
				Data: map[string]interface{}{
					"id": rc.PublicKey,
				},
			})
		}
	}
}

func (rc *RemoteClient) IPAddress() net.IP {
	//TODO: change this so that we don't get out of bounds too easily since IDs in a cluster jump by the size of the cluster
	return sharedutils.Int2IP(startingIP + uint32(rc.ID))
}

func (rc *RemoteClient) Netmask() int {
	return netmask
}

func (rc *RemoteClient) AllowedPeers(ctx context.Context, db *gorm.DB) []string {
	keys := []string{}
	rows, err := db.Raw("select public_key from remote_clients join node on remote_clients.mac=node.mac where public_key != ? and node.category_id = (select category_id from node where mac=?)", rc.PublicKey, rc.MAC).Rows()
	sharedutils.CheckError(err)
	for rows.Next() {
		var key string
		rows.Scan(&key)
		keys = append(keys, key)
	}
	return keys
}

type RemoteClientNode struct {
	MAC        string `json:"mac,omitempty"`
	CategoryId uint   `json:"category_id,omitempty"`
}

func (rc *RemoteClient) GetNode(ctx context.Context) RemoteClientNode {
	client := unifiedapiclient.NewFromConfig(ctx)

	resp := struct {
		Item RemoteClientNode
	}{}
	client.Call(ctx, "GET", "/api/v1/node/"+rc.MAC, &resp)
	return resp.Item
}

func (rc *RemoteClient) UpsertNode(ctx context.Context, rcn RemoteClientNode) error {
	client := unifiedapiclient.NewFromConfig(ctx)

	err := client.CallWithBody(ctx, "PATCH", "/api/v1/node/"+rcn.MAC, rcn, unifiedapiclient.DummyReply{})
	if err == nil {
		return nil
	}

	log.LoggerWContext(ctx).Info("Got an error while updating node " + rcn.MAC + ". Will try to create it instead")

	err = client.CallWithBody(ctx, "POST", "/api/v1/nodes", rcn, unifiedapiclient.DummyReply{})
	if err != nil {
		log.LoggerWContext(ctx).Error("Unable to upsert node " + rcn.MAC + ". Peer detection will have to rely on the previous role of the node. Error: " + err.Error())
	}

	return err
}
