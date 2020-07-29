package wgorchestrator

import (
	"encoding/base64"
	"encoding/binary"
	"errors"
	"net"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

const (
	AUTH_TIMESTAMP_START = 0
	AUTH_TIMESTAMP_END   = 8
	AUTH_RAND_START      = AUTH_TIMESTAMP_END
	AUTH_RAND_END        = 40
	AUTH_PUB_START       = AUTH_RAND_END
	AUTH_PUB_END         = 72
)

type Peer struct {
	WireguardIP      net.IP   `json:"wireguard_ip"`
	WireguardNetmask int      `json:"wireguard_netmask"`
	PublicKey        string   `json:"public_key"`
	AllowedPeers     []string `json:"allowed_peers,omitempty"`
}

var peers = map[string]*Peer{}

func (h *WgorchestratorHandler) handleGetProfile(c *gin.Context) {
	peerPubKey, err := b64KeyToBytes(c.Query("public_key"))
	if err != nil {
		log.LoggerWContext(c).Error("Error while decoding peer public key: " + err.Error())
		renderError(c, http.StatusBadRequest, errors.New("Public key is missing or doesn't have the right format"))
		return
	}
	shared := h.handlerSharedSecret(peerPubKey)

	authEncrypted, err := base64.URLEncoding.DecodeString(c.Query("auth"))
	sharedutils.CheckError(err)
	auth, err := DecryptMessage(shared[:], authEncrypted)
	sharedutils.CheckError(err)

	timestampBytes := auth[AUTH_TIMESTAMP_START:AUTH_TIMESTAMP_END]
	timestampInt := int64(binary.LittleEndian.Uint64(timestampBytes))
	timestamp := time.Unix(timestampInt, 0)

	if timestamp.Before(time.Now().Add(-5 * time.Second)) {
		renderError(c, http.StatusUnprocessableEntity, errors.New("This auth is too old, please try again"))
		return
	}

	authPeerPubKey := auth[AUTH_PUB_START:AUTH_PUB_END]

	for i := range authPeerPubKey {
		if authPeerPubKey[i] != peerPubKey[i] {
			renderError(c, http.StatusUnprocessableEntity, errors.New("Public key in auth message doesn't match the one that was provided"))
			return
		}
	}

	db := dbFromContext(c)
	rc, _ := GetOrCreateRemoteClient(db, c.Query("public_key"))

	c.JSON(http.StatusOK, Peer{
		WireguardIP:      rc.IPAddress(),
		WireguardNetmask: rc.Netmask(),
		PublicKey:        rc.PublicKey,
		AllowedPeers:     rc.AllowedPeers(db),
	})
}

func (h *WgorchestratorHandler) handleGetPeer(c *gin.Context) {
	db := dbFromContext(c)
	rc := RemoteClient{PublicKey: c.Param("id")}
	if db.Where(&rc).First(&rc); rc.ID != 0 {
		c.JSON(http.StatusOK, Peer{
			PublicKey:        rc.PublicKey,
			WireguardIP:      rc.IPAddress(),
			WireguardNetmask: rc.Netmask(),
		})
	} else {
		renderError(c, http.StatusNotFound, errors.New("Unable to find a peer with this identifier"))
	}
}

func (h *WgorchestratorHandler) handleGetEvents(c *gin.Context) {
	if lp := longPollFromContext(c); lp != nil {
		lp.SubscriptionHandler(c.Writer, c.Request)
	} else {
		renderError(c, http.StatusInternalServerError, errors.New("Unable to find events manager in context"))
	}
}

type Event struct {
	Type string                 `json:"type"`
	Data map[string]interface{} `json:"data"`
}

func (h *WgorchestratorHandler) handlePostEvents(c *gin.Context) {
	if lp := longPollFromContext(c); lp != nil {
		e := Event{}
		if err := c.BindJSON(&e); err == nil {
			lp.Publish(c.Param("k"), e)
		} else {
			renderError(c, http.StatusBadRequest, errors.New("Unable to parse JSON payload: "+err.Error()))
		}
	} else {
		renderError(c, http.StatusInternalServerError, errors.New("Unable to find events manager in context"))
	}
}

func (h *WgorchestratorHandler) handlerSharedSecret(peerPubKey [32]byte) [32]byte {
	return SharedSecret(h.privateKey, peerPubKey)
}

func (h *WgorchestratorHandler) handleGetServerChallenge(c *gin.Context) {
	peerPubKey, err := b64KeyToBytes(c.Query("public_key"))
	if err != nil {
		log.LoggerWContext(c).Error("Error while decoding peer public key: " + err.Error())
		renderError(c, http.StatusBadRequest, errors.New("Public key is missing or doesn't have the right format"))
		return
	}
	shared := h.handlerSharedSecret(peerPubKey)
	challenge := make([]byte, 8)
	binary.LittleEndian.PutUint64(challenge, uint64(time.Now().Unix()))

	// add random bytes at the beginning
	rand, err := GeneratePrivateKey()
	sharedutils.CheckError(err)
	challengeWithRand := append(challenge, rand[:]...)

	encryptedChallenge, err := EncryptMessage(shared[:], challengeWithRand)
	sharedutils.CheckError(err)

	c.JSON(http.StatusOK, gin.H{"challenge": base64.URLEncoding.EncodeToString(encryptedChallenge), "public_key": base64.URLEncoding.EncodeToString(h.publicKey[:])})
}
