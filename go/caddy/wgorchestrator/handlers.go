package wgorchestrator

import (
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"net/http"
	"regexp"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/inverse-inc/packetfence/go/common"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/remoteclients"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

func (h *WgorchestratorHandler) handleGetServerTime(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"timestamp": time.Now().Unix()})
}

func (h *WgorchestratorHandler) handleGetProfile(c *gin.Context) {
	peerPubKey, err := remoteclients.URLB64KeyToBytes(c.Query("public_key"))
	if err != nil {
		log.LoggerWContext(c).Error("Error while decoding peer public key: " + err.Error())
		renderError(c, http.StatusBadRequest, errors.New("Public key is missing or doesn't have the right format"))
		return
	}
	shared := h.handlerSharedSecret(peerPubKey)

	authEncrypted, err := base64.URLEncoding.DecodeString(c.Query("auth"))
	sharedutils.CheckError(err)
	auth, err := remoteclients.DecryptMessage(shared[:], authEncrypted)
	sharedutils.CheckError(err)

	timestampBytes := auth[remoteclients.AUTH_TIMESTAMP_START:remoteclients.AUTH_TIMESTAMP_END]
	timestampInt := int64(binary.LittleEndian.Uint64(timestampBytes))
	timestamp := time.Unix(timestampInt, 0)

	if timestamp.Before(time.Now().Add(-5 * time.Second)) {
		renderError(c, http.StatusUnprocessableEntity, errors.New("This auth is too old, please try again"))
		return
	}

	authPeerPubKey := auth[remoteclients.AUTH_PUB_START:remoteclients.AUTH_PUB_END]

	for i := range authPeerPubKey {
		if authPeerPubKey[i] != peerPubKey[i] {
			renderError(c, http.StatusUnprocessableEntity, errors.New("Public key in auth message doesn't match the one that was provided"))
			return
		}
	}

	db := dbFromContext(c)

	username := c.Request.Header.Get("X-PacketFence-Username")
	var categoryId int
	var unregdate string
	if username != "" {
		var role string
		var err error
		categoryId, role, unregdate, err = h.getRoleForUsername(c, username)
		if err != nil {
			log.LoggerWContext(c).Error("Error while communicating with API: " + err.Error())
			renderError(c, http.StatusInternalServerError, errors.New("Unable to communicate with API to obtain role for your username"))
			return
		}
		if role == "" {
			renderError(c, http.StatusForbidden, errors.New("Access denied: No role matched for your username"))
			return
		} else {
			log.LoggerWContext(c).Info("Matched role " + role + " for " + username)
		}
	} else {
		log.LoggerWContext(c).Warn("No X-PacketFence-Username in the request. Assuming we're running in test mode.")
		categoryId = 1
	}

	rc, err := remoteclients.GetOrCreateRemoteClient(c, db, c.Query("public_key"), common.NodeInfo{
		Node: common.Node{
			MAC:          c.Query("mac"),
			Computername: c.Query("hostname"),
			PID:          username,
			Unregdate:    unregdate,
			Status:       "reg",
			CategoryID:   json.Number(strconv.Itoa(categoryId)),
		},
	})

	if err != nil {
		log.LoggerWContext(c).Error("Unable to GetOrCreateRemoteClient: " + err.Error())
		renderError(c, http.StatusInternalServerError, errors.New("Unable to GetOrCreateRemoteClient. See server-side logs for details."))
	}

	profile := remoteclients.Peer{
		WireguardIP:             rc.IPAddress(),
		WireguardNetmask:        rc.Netmask(),
		AllowedPeers:            rc.AllowedPeers(c, db),
		NamesToResolve:          rc.NamesToResolve(c, db),
		DomainsToResolve:        rc.DomainsToResolve(c, db),
		ACLs:                    rc.ACLs(c, db),
		Routes:                  rc.Routes(c, db),
		IsGateway:               rc.IsGateway(c, db),
		STUNServer:              rc.STUNServer(c, db),
		InternalDomainToResolve: rc.InternalDomainToResolve(c, db),
	}

	c.JSON(http.StatusOK, profile)
}

func (h *WgorchestratorHandler) handleGetPeer(c *gin.Context) {
	db := dbFromContext(c)
	rc := remoteclients.RemoteClient{PublicKey: c.Param("id")}
	if db.Where(&rc).First(&rc); rc.ID != 0 {
		c.JSON(http.StatusOK, remoteclients.Peer{
			PublicKey:        rc.PublicKey,
			WireguardIP:      rc.IPAddress(),
			WireguardNetmask: rc.Netmask(),
			IsGateway:        rc.IsGateway(c, db),
			Hostname:         rc.GetNode(c).Computername,
		})
	} else {
		renderError(c, http.StatusNotFound, errors.New("Unable to find a peer with this identifier"))
	}
}

func (h *WgorchestratorHandler) handleGetEvents(c *gin.Context) {
	if lp := longPollFromContext(c); lp != nil {
		k := c.Query("category")
		if h.isPrivEventCategory(k) {
			renderError(c, http.StatusForbidden, errors.New("Cannot use this event category in this API call, use /api/v1/remote_clients/my_events"))
			return
		}
		lp.SubscriptionHandler(c.Writer, c.Request)
	} else {
		renderError(c, http.StatusInternalServerError, errors.New("Unable to find events manager in context"))
	}
}

var privRegexp = regexp.MustCompile(`^` + remoteclients.PRIVATE_EVENTS_SUFFIX)

func (h *WgorchestratorHandler) isPrivEventCategory(category string) bool {
	return privRegexp.MatchString(category)
}

func (h *WgorchestratorHandler) handlePostEvents(c *gin.Context) {
	if lp := longPollFromContext(c); lp != nil {
		e := remoteclients.Event{}
		if err := c.BindJSON(&e); err == nil {
			k := c.Param("k")
			if h.isPrivEventCategory(k) {
				renderError(c, http.StatusForbidden, errors.New("Cannot use this event category in this API call, use /api/v1/remote_clients/my_events"))
				return
			}
			lp.Publish(k, e)
		} else {
			renderError(c, http.StatusBadRequest, errors.New("Unable to parse JSON payload: "+err.Error()))
		}
	} else {
		renderError(c, http.StatusInternalServerError, errors.New("Unable to find events manager in context"))
	}
}

func (h *WgorchestratorHandler) handlerSharedSecret(peerPubKey [32]byte) [32]byte {
	return remoteclients.SharedSecret(h.privateKey, peerPubKey)
}

func (h *WgorchestratorHandler) handleGetServerChallenge(c *gin.Context) {
	peerPubKey, err := remoteclients.URLB64KeyToBytes(c.Query("public_key"))
	if err != nil {
		log.LoggerWContext(c).Error("Error while decoding peer public key: " + err.Error())
		renderError(c, http.StatusBadRequest, errors.New("Public key is missing or doesn't have the right format"))
		return
	}
	shared := h.handlerSharedSecret(peerPubKey)
	challenge := make([]byte, 8)
	binary.LittleEndian.PutUint64(challenge, uint64(time.Now().Unix()))

	// add random bytes at the beginning
	rand, err := remoteclients.GeneratePrivateKey()
	sharedutils.CheckError(err)
	challengeWithRand := append(challenge, rand[:]...)

	encryptedChallenge, err := remoteclients.EncryptMessage(shared[:], challengeWithRand)
	sharedutils.CheckError(err)

	c.JSON(http.StatusOK, gin.H{"challenge": base64.URLEncoding.EncodeToString(encryptedChallenge), "public_key": base64.URLEncoding.EncodeToString(h.publicKey[:])})
}

func (h *WgorchestratorHandler) handleGetPrivEvents(c *gin.Context) {
	peerPubKey, err := remoteclients.URLB64KeyToBytes(c.Query("public_key"))
	if err != nil {
		c.JSON(http.StatusBadRequest, "Unable to base64 decode the public key")
		return
	}

	if _, found := c.GetQuery("category"); found {
		renderError(c, http.StatusForbidden, errors.New("You cannot specify a category on this API call"))
		return
	}

	shared := h.handlerSharedSecret(peerPubKey)

	authEncrypted, err := base64.URLEncoding.DecodeString(c.Query("auth"))
	sharedutils.CheckError(err)
	auth, err := remoteclients.DecryptMessage(shared[:], authEncrypted)
	sharedutils.CheckError(err)

	timestampBytes := auth[remoteclients.AUTH_TIMESTAMP_START:remoteclients.AUTH_TIMESTAMP_END]
	timestampInt := int64(binary.LittleEndian.Uint64(timestampBytes))
	timestamp := time.Unix(timestampInt, 0)

	if timestamp.Before(time.Now().Add(-5 * time.Second)) {
		renderError(c, http.StatusUnprocessableEntity, errors.New("This auth is too old, please try again"))
		return
	}

	if lp := longPollFromContext(c); lp != nil {
		q := c.Request.URL.Query()
		q.Set("category", remoteclients.PRIVATE_EVENTS_SUFFIX+c.Query("public_key"))
		c.Request.URL.RawQuery = q.Encode()

		lp.SubscriptionHandler(c.Writer, c.Request)
	} else {
		renderError(c, http.StatusInternalServerError, errors.New("Unable to find events manager in context"))
	}
}

func (h *WgorchestratorHandler) getRoleForUsername(c *gin.Context, username string) (int, string, string, error) {
	var resp struct {
		CategoryId int    `json:"category_id"`
		Role       string `json:"role"`
		Unregdate  string `json:"unregdate"`
	}
	err := unifiedapiclient.NewFromConfig(c).CallWithBody(c, "POST", "/api/v1/authentication/role_authentication", gin.H{"username": username}, &resp)
	return resp.CategoryId, resp.Role, resp.Unregdate, err
}
