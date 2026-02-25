package eslogtailer

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/gin-gonic/gin"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
)

const maxSessionIdleTime = 5 * time.Minute
const defaultPollTimeout = 30 * time.Second

var handledPath = regexp.MustCompile(`^/api/v1/eslogs/tail`)

func init() {
	caddy.RegisterModule(ESLogTailerHandler{})
	httpcaddyfile.RegisterHandlerDirective("es-log-tailer", utils.ParseCaddyfile[ESLogTailerHandler])
}

func (ESLogTailerHandler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.es-log-tailer",
		New: func() caddy.Module {
			return &ESLogTailerHandler{}
		},
	}
}

type ESLogTailerHandler struct {
	router              *gin.Engine
	sessions            map[string]*ESTailingSession
	sessionsLock        *sync.RWMutex
	maintenanceLauncher *sync.Once
	esClient            *ESClient
	fieldMapping        *ESFieldMapping
	indexPattern        string
	aggField            string
}

func (m *ESLogTailerHandler) Provision(_ caddy.Context) error {
	ctx := log.LoggerNewContext(context.Background())
	return m.buildHandler(ctx)
}

func (m *ESLogTailerHandler) buildHandler(ctx context.Context) error {
	m.esClient = NewESClient()
	m.fieldMapping = NewESFieldMappingFromEnv()

	nsPath := os.Getenv("K8S_NAMESPACE_PATH")
	if nsPath == "" {
		log.LoggerWContext(ctx).Warn("es-log-tailer: K8S_NAMESPACE_PATH not set, plugin disabled")
		return nil
	}
	nsData, err := os.ReadFile(nsPath)
	if err != nil {
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("es-log-tailer: failed to read K8S_NAMESPACE_PATH (%s): %s, plugin disabled", nsPath, err))
		return nil
	}
	k8sNamespace := strings.TrimSpace(string(nsData))
	if k8sNamespace == "" {
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("es-log-tailer: K8S_NAMESPACE_PATH (%s) was empty, plugin disabled", nsPath))
		return nil
	}
	m.indexPattern = "prod-" + k8sNamespace + "-*"

	m.aggField = os.Getenv("ES_AGG_FIELD")
	if m.aggField == "" {
		m.aggField = "kubernetes.container_name.keyword"
	}

	m.sessions = map[string]*ESTailingSession{}
	if m.sessionsLock == nil {
		m.sessionsLock = &sync.RWMutex{}
	}
	if m.maintenanceLauncher == nil {
		m.maintenanceLauncher = &sync.Once{}
	}

	router := gin.Default()
	esLogTailerApi := router.Group("/api/v1/eslogs/tail")

	esLogTailerApi.OPTIONS("", m.optionsSessions)
	esLogTailerApi.POST("", m.createNewSession)
	esLogTailerApi.GET("/:id", m.getSession)
	esLogTailerApi.POST("/:id/touch", m.touchSession)
	esLogTailerApi.DELETE("/:id", m.deleteSession)

	m.router = router

	log.LoggerWContext(ctx).Info(fmt.Sprintf("es-log-tailer plugin initialized, ES at %s, index_pattern=%s, agg_field=%s", m.esClient.baseURL, m.indexPattern, m.aggField))

	return nil
}

func (h *ESLogTailerHandler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	if h.router == nil {
		return next.ServeHTTP(w, r)
	}

	ctx := r.Context()

	defer panichandler.Http(ctx, w)

	h.maintenanceLauncher.Do(func() {
		go func() {
			ctx := log.LoggerNewContext(context.Background())
			for {
				func() {
					h.sessionsLock.Lock()
					defer h.sessionsLock.Unlock()
					expireAt := time.Now().Add(-maxSessionIdleTime)
					for sessionId, session := range h.sessions {
						if session.LastUsedAt().Before(expireAt) {
							log.LoggerWContext(ctx).Info("Deleting inactive ES tailing session " + sessionId)
							delete(h.sessions, sessionId)
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

func (s *ESLogTailerHandler) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	c.Next()
	return nil
}

func (l *ESLogTailerHandler) Cleanup() error {
	return nil
}

func (l *ESLogTailerHandler) Validate() error {
	return nil
}
