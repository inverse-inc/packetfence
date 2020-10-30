package remoteclients

import (
	"context"
	"net"
	"strconv"
	"time"

	"github.com/inverse-inc/packetfence/go/common"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/sharedutils"
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

func GetOrCreateRemoteClient(ctx context.Context, db *gorm.DB, publicKey string, mac string, categoryId int) (*RemoteClient, error) {
	rc := RemoteClient{MAC: mac}
	rcn, err := rc.GetNode(ctx)

	if err != nil {
		return nil, err
	}

	categoryIdChanged := categoryId != rcn.CategoryID_int()

	rcn.MAC = mac
	rcn.CategoryID = strconv.Itoa(categoryId)
	err = rcn.Upsert(ctx)
	if err != nil {
		log.LoggerWContext(ctx).Error("Unable to upsert node, role detection will rely on the previous role")
	}

	db.Where("public_key = ?", publicKey).First(&rc)
	rc.MAC = mac
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

func (rc *RemoteClient) GetNode(ctx context.Context) (common.NodeInfo, error) {
	return common.FetchNodeInfo(ctx, rc.MAC)
}
