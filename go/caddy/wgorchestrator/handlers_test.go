package wgorchestrator

import (
	"context"
	"encoding/base64"
	"encoding/binary"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	httpexpect "github.com/gavv/httpexpect/v2"
	"github.com/inverse-inc/packetfence/go/common"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/remoteclients"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/jinzhu/gorm"
)

var handler WgorchestratorHandler
var testServer *httptest.Server

func init() {
	var err error
	handler, err = buildWgorchestratorHandler(context.Background())
	sharedutils.CheckError(err)
	testServer = httptest.NewServer(handler.router)
}

func TestHandleGetProfile(t *testing.T) {
	ctx := context.Background()
	e := httpexpect.New(t, testServer.URL)

	priv, err := remoteclients.GeneratePrivateKey()
	sharedutils.CheckError(err)
	pub, err := remoteclients.GeneratePublicKey(priv)
	sharedutils.CheckError(err)

	// Delete existing clients + add a another client
	gormdb, err := gorm.Open("mysql", db.ReturnURIFromConfig(context.Background()))
	gormdb.DB().Query("delete from node")
	gormdb.DB().Query("delete from remote_clients")
	gormdb.DB().Query("insert into node(mac, category_id) VALUES('aa:bb:cc:dd:ee:ff', 1)")
	peers := []string{"aa:bb:cc:dd:ee:ff"}
	for _, peer := range peers {
		remoteclients.GetOrCreateRemoteClient(ctx, gormdb, peer, common.NodeInfo{Node: common.Node{MAC: peer, CategoryID: "1"}})
	}

	m := e.GET("/api/v1/remote_clients/server_challenge").WithQuery("public_key", base64.URLEncoding.EncodeToString(pub[:])).
		Expect().
		Status(http.StatusOK).
		JSON().
		Object().
		ContainsKey("challenge").
		ContainsKey("public_key").
		Raw()

	encryptedChallenge, err := base64.URLEncoding.DecodeString(m["challenge"].(string))
	sharedutils.CheckError(err)

	serverPublicKey, err := remoteclients.URLB64KeyToBytes(m["public_key"].(string))
	sharedutils.CheckError(err)

	sharedSecret := remoteclients.SharedSecret(priv, serverPublicKey)

	challenge, err := remoteclients.DecryptMessage(sharedSecret[:], []byte(encryptedChallenge))
	sharedutils.CheckError(err)

	challengeInt := int64(binary.LittleEndian.Uint64(challenge[remoteclients.AUTH_TIMESTAMP_START:remoteclients.AUTH_TIMESTAMP_END]))

	challengeTime := time.Unix(challengeInt, 0)

	if challengeTime.IsZero() {
		t.Error("Challenge time is the 0 value")
	}

	if challengeTime.After(time.Now()) {
		t.Error("Challenge time is after now")
	}

	if challengeTime.Before(time.Now().Add(-5 * time.Second)) {
		t.Error("Challenge time is older than 5 seconds")
	}

	challenge = append(challenge, pub[:]...)

	encryptedChallengeRaw, err := remoteclients.EncryptMessage(sharedSecret[:], challenge)
	sharedutils.CheckError(err)

	m = e.GET("/api/v1/remote_clients/profile").
		WithQuery("auth", base64.URLEncoding.EncodeToString(encryptedChallengeRaw)).
		WithQuery("public_key", base64.URLEncoding.EncodeToString(pub[:])).
		WithQuery("mac", "00:11:22:33:44:55").
		Expect().
		Status(http.StatusOK).
		JSON().
		Object().
		ContainsKey("wireguard_ip").
		ContainsKey("wireguard_netmask").
		ContainsKey("allowed_peers").
		ContainsMap(map[string]interface{}{"allowed_peers": peers}).
		Raw()

	for _, peer := range peers {
		e.GET("/api/v1/remote_clients/peer/" + peer).
			Expect().
			Status(http.StatusOK).
			JSON().
			Object().
			ContainsKey("wireguard_ip").
			ContainsKey("wireguard_netmask").
			ContainsKey("public_key")
	}

	gormdb.DB().Query("delete from remote_clients")
	gormdb.DB().Query("delete from node")
}

func TestPrivEventsRestriction(t *testing.T) {
	e := httpexpect.New(t, testServer.URL)
	e.GET("/api/v1/remote_clients/events").WithQuery("category", remoteclients.PRIVATE_EVENTS_SUFFIX+"something").
		Expect().
		Status(http.StatusForbidden).
		JSON().
		Object().
		ContainsKey("message")

	e.GET("/api/v1/remote_clients/events").WithQuery("category", "not-"+remoteclients.PRIVATE_EVENTS_SUFFIX+"something").WithQuery("timeout", "1").
		Expect().
		Status(http.StatusOK).
		JSON().
		Object().
		ContainsKey("timestamp")

}

func TestHandleGetPrivEvents(t *testing.T) {
	priv, err := remoteclients.GeneratePrivateKey()
	sharedutils.CheckError(err)
	pub, err := remoteclients.GeneratePublicKey(priv)
	sharedutils.CheckError(err)

	shared := remoteclients.SharedSecret(priv, handler.publicKey)
	challenge := make([]byte, 8)
	binary.LittleEndian.PutUint64(challenge, uint64(time.Now().Unix()))
	encryptedChallenge, err := remoteclients.EncryptMessage(shared[:], challenge)
	sharedutils.CheckError(err)

	e := httpexpect.New(t, testServer.URL)
	e.GET("/api/v1/remote_clients/my_events").
		WithQuery("timeout", "1").
		WithQuery("auth", base64.URLEncoding.EncodeToString(encryptedChallenge)).
		WithQuery("public_key", base64.URLEncoding.EncodeToString(pub[:])).
		Expect().
		Status(http.StatusOK).
		JSON().
		Object().
		ContainsKey("timestamp")

	e.GET("/api/v1/remote_clients/my_events").
		WithQuery("timeout", "1").
		WithQuery("auth", base64.URLEncoding.EncodeToString(encryptedChallenge)).
		WithQuery("public_key", base64.URLEncoding.EncodeToString(pub[:])).
		WithQuery("category", remoteclients.PRIVATE_EVENTS_SUFFIX+base64.URLEncoding.EncodeToString(pub[:])).
		Expect().
		Status(http.StatusForbidden).
		JSON().
		Object().
		ContainsKey("message")

	time.Sleep(5 * time.Second)

	e.GET("/api/v1/remote_clients/my_events").
		WithQuery("timeout", "1").
		WithQuery("auth", base64.URLEncoding.EncodeToString(encryptedChallenge)).
		WithQuery("public_key", base64.URLEncoding.EncodeToString(pub[:])).
		Expect().
		Status(http.StatusUnprocessableEntity).
		JSON().
		Object().
		ContainsKey("message")

}
