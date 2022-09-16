package logtailer

import (
	"net/http"
	"regexp"
	"sync"
	"time"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/gin-gonic/gin"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2"
	"github.com/jcuga/golongpoll"
)

const maxSessionIdleTime = 5 * time.Minute
const defaultPollTimeout = 30 * time.Second

var handledPath = regexp.MustCompile(`^/api/v1/logs/tail`)

// Register the plugin in caddy
func init() {
	caddy.RegisterModule(LogTailerHandler{})
	httpcaddyfile.RegisterHandlerDirective("log-tailer", caddy2.ParseCaddyfile[LogTailerHandler])
}

type PrettyTokenInfo struct {
	AdminActions []string  `json:"admin_actions"`
	AdminRoles   []string  `json:"admin_roles"`
	Username     string    `json:"username"`
	ExpiresAt    time.Time `json:"expires_at"`
}

type LogTailerHandler struct {
	caddy2.ModuleBase
	router              *gin.Engine
	eventsManager       *golongpoll.LongpollManager
	sessions            map[string]*TailingSession
	sessionsLock        sync.RWMutex
	maintenanceLauncher sync.Once
}

func (h LogTailerHandler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID:  "http.handlers.log-tailer",
		New: func() caddy.Module { return &LogTailerHandler{} },
	}
}

func (h *LogTailerHandler) Provision(ctx caddy.Context) error {
	var err error
	h.eventsManager, err = golongpoll.StartLongpoll(golongpoll.Options{
		LoggingEnabled:     (sharedutils.EnvOrDefault("LOG_LEVEL", "") == "debug"),
		MaxEventBufferSize: 1000,
		// Events stay for up to 5 minutes
		EventTimeToLiveSeconds:         int(maxSessionIdleTime / time.Second),
		DeleteEventAfterFirstRetrieval: true,
	})

	sharedutils.CheckError(err)
	h.sessions = map[string]*TailingSession{}
	h.sessionsLock = sync.RWMutex{}
	h.maintenanceLauncher = sync.Once{}
	router := gin.Default()
	logTailerApi := router.Group("/api/v1/logs/tail")
	logTailerApi.OPTIONS("", h.optionsSessions)
	logTailerApi.POST("", h.createNewSession)
	logTailerApi.GET("/:id", h.getSession)
	logTailerApi.POST("/:id/touch", h.touchSession)
	logTailerApi.DELETE("/:id", h.deleteSession)
	h.router = router

	return nil
}

func (h *LogTailerHandler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	ctx := r.Context()
	defer panichandler.Http(ctx, w)

	h.maintenanceLauncher.Do(func() {
		go func() {
			for {
				func() {
					h.sessionsLock.Lock()
					defer h.sessionsLock.Unlock()
					expireAt := time.Now().Add(-maxSessionIdleTime)
					for sessionId, session := range h.sessions {
						if session.lastUsedAt.Before(expireAt) {
							log.LoggerWContext(ctx).Info("Deleting inactive tailing session " + sessionId)
							h._deleteSession(sessionId, session)
						}
					}
				}()
				time.Sleep(1 * time.Second)
			}
		}()
	})

	if handledPath.MatchString(r.URL.Path) {
		h.router.ServeHTTP(w, r)
		return nil
	}

	return next.ServeHTTP(w, r)
}
