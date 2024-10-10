package logtailer

import (
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

var logs pfconfigdriver.SyslogFiles

func (h *LogTailerHandler) optionsSessions(c *gin.Context) {
	pfconfigdriver.FetchDecodeSocketCache(c, &logs)
	files := []gin.H{}

	sort.Slice(logs.Element, func(i, j int) bool {
		return strings.ToLower(logs.Element[i].Description) < strings.ToLower(logs.Element[j].Description)
	})

	for _, log := range logs.Element {
		files = append(files, gin.H{"text": log.Description, "value": log.Name})
	}

	c.JSON(http.StatusOK, gin.H{
		"meta": gin.H{
			"filter": gin.H{
				"type":        "string",
				"required":    false,
				"default":     nil,
				"placeholder": nil,
			},
			"filter_is_regexp": gin.H{
				"type":        "string",
				"required":    false,
				"default":     nil,
				"placeholder": false,
			},
			"files": gin.H{
				"type":        "array",
				"required":    true,
				"placeholder": nil,
				"default":     nil,
				"item": gin.H{
					"type":        "string",
					"required":    true,
					"placeholder": nil,
					"default":     nil,
					"allowed":     files,
				},
			},
		},
	})
}

func (h *LogTailerHandler) createNewSession(c *gin.Context) {
	h.sessionsLock.Lock()
	defer h.sessionsLock.Unlock()

	params := struct {
		Files          []string `json:"files"`
		Filter         string   `json:"filter"`
		FilterIsRegexp bool     `json:"filter_is_regexp"`
	}{}

	sessionId := uuid.New().String()

	if err := c.ShouldBindJSON(&params); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Unable to parse JSON payload"})
		return
	}

	if len(params.Files) == 0 {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"message": "No files were specified"})
	}

	var filterRe *regexp.Regexp
	if params.Filter == "" {
		filterRe = regexp.MustCompile(`.*`)
	} else if params.FilterIsRegexp {
		filterRe = regexp.MustCompile(`(?i)` + params.Filter)
	} else {
		// Simple match
		filterRe = regexp.MustCompile(`(?i).*` + regexp.QuoteMeta(params.Filter) + `.*`)
	}

	h.sessions[sessionId] = NewTailingSession(params.Files, filterRe)
	if err := h.sessions[sessionId].Start(sessionId, h.eventsManager); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": fmt.Sprintf("Unable to start tailing session: %s", err)})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Tailing session started", "session_id": sessionId})
}

func (h *LogTailerHandler) getSession(c *gin.Context) {
	func() {
		h.sessionsLock.RLock()
		defer h.sessionsLock.RUnlock()

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

		h.sessions[sessionId].Touch()
	}()

	h.eventsManager.SubscriptionHandler(c.Writer, c.Request)
}

func (h *LogTailerHandler) touchSession(c *gin.Context) {
	h.sessionsLock.RLock()
	defer h.sessionsLock.RUnlock()

	sessionId := c.Param("id")

	if _, ok := h.sessions[sessionId]; !ok {
		c.JSON(http.StatusNotFound, gin.H{"message": "Unable to find a session with this identifier"})
		return
	}

	h.sessions[sessionId].Touch()

	c.JSON(http.StatusOK, gin.H{"message": "Touched session"})
}

func (h *LogTailerHandler) deleteSession(c *gin.Context) {
	h.sessionsLock.Lock()
	defer h.sessionsLock.Unlock()

	sessionId := c.Param("id")
	if session, ok := h.sessions[sessionId]; ok {
		h._deleteSession(sessionId, session)
		c.JSON(http.StatusOK, gin.H{"message": "Deleted the session"})
	} else {
		c.JSON(http.StatusNotFound, gin.H{"message": "Unable to find this session"})
	}
}

func (h *LogTailerHandler) _deleteSession(sessionId string, session *TailingSession) {
	session.Stop()
	delete(h.sessions, sessionId)
}
