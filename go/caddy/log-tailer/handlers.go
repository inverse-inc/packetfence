package logtailer

import (
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

func (h LogTailerHandler) createNewSession(c *gin.Context) {
	params := struct {
		Files []string `json:"files"`
	}{}

	sessionId := uuid.New().String()

	if err := c.ShouldBindJSON(&params); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Unable to parse JSON payload"})
		return
	}

	h.sessions[sessionId] = NewTailingSession(params.Files)
	if err := h.sessions[sessionId].Start(sessionId, h.eventsManager); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": fmt.Sprintf("Unable to start tailing session: %s", err)})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Tailing session started", "session_id": sessionId})
}

func (h LogTailerHandler) getSession(c *gin.Context) {
	var err error

	sessionId := c.Param("id")

	if _, ok := h.sessions[sessionId]; !ok {
		c.JSON(http.StatusNotFound, gin.H{"message": "Unable to find a session with this identifier"})
		return
	}

	char := "?"
	if strings.Contains(c.Request.URL.String(), "?") {
		char = "&"
	}

	timeout := ""
	if _, ok := c.GetQuery("timeout"); !ok {
		timeout = fmt.Sprintf("&timeout=%d", defaultPollTimeout/time.Second)
	}

	c.Request.URL, err = url.Parse(c.Request.URL.String() + char + "category=" + sessionId + "&since_time=0" + timeout)
	sharedutils.CheckError(err)
	h.eventsManager.SubscriptionHandler(c.Writer, c.Request)
}

func (h LogTailerHandler) deleteSession(c *gin.Context) {
	sessionId := c.Param("id")
	if session, ok := h.sessions[sessionId]; ok {
		session.Stop()
		delete(h.sessions, sessionId)
		c.JSON(http.StatusOK, gin.H{"message": "Deleted the session"})
	} else {
		c.JSON(http.StatusNotFound, gin.H{"message": "Unable to find this session"})
	}
}
