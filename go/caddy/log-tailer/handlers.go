package logtailer

import (
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

func pflog(log string) string {
	return "/usr/local/pf/logs/" + log
}

func (h LogTailerHandler) optionsSessions(c *gin.Context) {
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
					"allowed": []gin.H{
						gin.H{
							"text":  "Global syslog (/var/log/messages)",
							"value": "/var/log/messages",
						},
						gin.H{
							"text":  "httpd.aaa Apache access log",
							"value": pflog("httpd.aaa.access"),
						},
						gin.H{
							"text":  "httpd.portal Apache access log",
							"value": pflog("httpd.portal.access"),
						},
						gin.H{
							"text":  "httpd.portal Apache error log",
							"value": pflog("httpd.portal.error"),
						},
						gin.H{
							"text":  "httpd.webservices Apache access log",
							"value": pflog("httpd.webservices.access"),
						},
						gin.H{
							"text":  "httpd.webservices Apache error log",
							"value": pflog("httpd.webservices.error"),
						},
						gin.H{
							"text":  "MariaDB log",
							"value": pflog("mariadb_error.log"),
						},
						gin.H{
							"text":  "General PacketFence log (packetfence.log)",
							"value": pflog("packetfence.log"),
						},
						gin.H{
							"text":  "pfconfig service log",
							"value": pflog("pfconfig.log"),
						},
						gin.H{
							"text":  "pfdetect service log",
							"value": pflog("pfdetect.log"),
						},
						gin.H{
							"text":  "pfdhcplistener service log",
							"value": pflog("pfdhcplistener.log"),
						},
						gin.H{
							"text":  "pfdhcp service log",
							"value": pflog("pfdhcp.log"),
						},
						gin.H{
							"text":  "pfdns service log",
							"value": pflog("pfdns.log"),
						},
						gin.H{
							"text":  "pffilter service log",
							"value": pflog("pffilter.log"),
						},
						gin.H{
							"text":  "pfmon service log",
							"value": pflog("pfmon.log"),
						},
						gin.H{
							"text":  "pfsso service log",
							"value": pflog("pfsso.log"),
						},
						gin.H{
							"text":  "pfstats service log",
							"value": pflog("pfdetect.log"),
						},
						gin.H{
							"text":  "RADIUS CLI log",
							"value": pflog("radius-cli.log"),
						},
						gin.H{
							"text":  "RADIUS eduroam log",
							"value": pflog("radius-eduroam.log"),
						},
						gin.H{
							"text":  "RADIUS load-balancer log (only in cluster)",
							"value": pflog("radius-load_balancer.log"),
						},
						gin.H{
							"text":  "RADIUS authentication log",
							"value": pflog("radius.log"),
						},
						gin.H{
							"text":  "Security events log",
							"value": pflog("security_event.log"),
						},
					},
				},
			},
		},
	})
}

func (h LogTailerHandler) createNewSession(c *gin.Context) {
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

func (h LogTailerHandler) getSession(c *gin.Context) {
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

func (h LogTailerHandler) deleteSession(c *gin.Context) {
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

func (h LogTailerHandler) _deleteSession(sessionId string, session *TailingSession) {
	session.Stop()
	delete(h.sessions, sessionId)
}
