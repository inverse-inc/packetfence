package logtailer

import (
	"context"
	"net/http"
	"regexp"
	"sync"
	"time"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/gin-gonic/gin"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
	"github.com/jcuga/golongpoll"
)

const maxSessionIdleTime = 5 * time.Minute
const defaultPollTimeout = 30 * time.Second

var handledPath = regexp.MustCompile(`^/api/v1/logs/tail`)

// Register the plugin in caddy
func init() {
	caddy.RegisterModule(LogTailerHandler{})
	httpcaddyfile.RegisterHandlerDirective("log-tailer", utils.ParseCaddyfile[LogTailerHandler])
}

// CaddyModule returns the Caddy module information.
func (LogTailerHandler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.log-tailer",
		New: func() caddy.Module {
			return &LogTailerHandler{}
		},
	}
}

type PrettyTokenInfo struct {
	AdminActions []string  `json:"admin_actions"`
	AdminRoles   []string  `json:"admin_roles"`
	Username     string    `json:"username"`
	ExpiresAt    time.Time `json:"expires_at"`
}

type LogTailerHandler struct {
	router              *gin.Engine
	eventsManager       *golongpoll.LongpollManager
	sessions            map[string]*TailingSession
	sessionsLock        sync.RWMutex
	maintenanceLauncher sync.Once
}

// Setup the log-tailer middleware
// Also loads the pfconfig resources and registers them in the pool
func (m *LogTailerHandler) Provision(_ caddy.Context) error {
	ctx := log.LoggerNewContext(context.Background())
	err := m.buildLogTailerHandler(ctx)
	if err != nil {
		return err
	}

	return nil
}

func (m *LogTailerHandler) buildLogTailerHandler(ctx context.Context) error {
	var err error
	m.eventsManager, err = golongpoll.StartLongpoll(golongpoll.Options{
		LoggingEnabled:     (sharedutils.EnvOrDefault("LOG_LEVEL", "") == "debug"),
		MaxEventBufferSize: 1000,
		// Events stay for up to 5 minutes
		EventTimeToLiveSeconds:         int(maxSessionIdleTime / time.Second),
		DeleteEventAfterFirstRetrieval: true,
	})
	sharedutils.CheckError(err)

	m.sessions = map[string]*TailingSession{}
	m.sessionsLock = sync.RWMutex{}

	m.maintenanceLauncher = sync.Once{}

	router := gin.Default()
	logTailerApi := router.Group("/api/v1/logs/tail")

	logTailerApi.OPTIONS("", m.optionsSessions)
	logTailerApi.POST("", m.createNewSession)
	logTailerApi.GET("/:id", m.getSession)
	logTailerApi.POST("/:id/touch", m.touchSession)
	logTailerApi.DELETE("/:id", m.deleteSession)

	m.router = router

	return nil
}

func (h *LogTailerHandler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	ctx := r.Context()

	defer panichandler.Http(ctx, w)

	h.maintenanceLauncher.Do(func() {
		go func() {
			ctx := r.Context()
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

func (s *LogTailerHandler) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	c.Next()
	return nil
}

func (l *LogTailerHandler) Cleanup() error {
	return nil
}

func (l *LogTailerHandler) Validate() error {
	return nil
}
