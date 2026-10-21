package eslogtailer

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"regexp"
	"strings"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/gin-gonic/gin"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
)

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
	router       *gin.Engine
	esClient     *ESClient
	fieldMapping *ESFieldMapping
	indexPattern  string
	aggField     string
}

func (m *ESLogTailerHandler) Provision(_ caddy.Context) error {
	ctx := log.LoggerNewContext(context.Background())
	return m.buildHandler(ctx)
}

func (m *ESLogTailerHandler) buildHandler(ctx context.Context) error {
	l := log.LoggerWContext(ctx)

	// Validate required env vars upfront
	kibanaHost := os.Getenv("KIBANA_HOST")
	nsPath := os.Getenv("K8S_NAMESPACE_PATH")

	missing := []string{}
	if kibanaHost == "" {
		missing = append(missing, "KIBANA_HOST")
	}
	if nsPath == "" {
		missing = append(missing, "K8S_NAMESPACE_PATH")
	}
	if len(missing) > 0 {
		l.Warn(fmt.Sprintf("es-log-tailer: missing required env vars %v, plugin disabled", missing))
		return nil
	}

	// Read namespace from file
	nsData, err := os.ReadFile(nsPath)
	if err != nil {
		l.Warn(fmt.Sprintf("es-log-tailer: failed to read K8S_NAMESPACE_PATH (%s): %s, plugin disabled", nsPath, err))
		return nil
	}
	k8sNamespace := strings.TrimSpace(string(nsData))
	if k8sNamespace == "" {
		l.Warn(fmt.Sprintf("es-log-tailer: K8S_NAMESPACE_PATH (%s) was empty, plugin disabled", nsPath))
		return nil
	}

	m.esClient = NewESClient()
	m.fieldMapping = NewESFieldMappingFromEnv()
	m.indexPattern = "prod-" + k8sNamespace + "-*"

	m.aggField = os.Getenv("ES_AGG_FIELD")
	if m.aggField == "" {
		m.aggField = "kubernetes.container_name.keyword"
	}

	router := gin.Default()
	esLogTailerApi := router.Group("/api/v1/eslogs/tail")

	esLogTailerApi.OPTIONS("", m.optionsSessions)
	esLogTailerApi.POST("", m.pollHandler)

	m.router = router

	l.Info(fmt.Sprintf("es-log-tailer: initialized index_pattern=%s agg_field=%s", m.indexPattern, m.aggField))

	return nil
}

func (h *ESLogTailerHandler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	if h.router == nil {
		return next.ServeHTTP(w, r)
	}

	ctx := r.Context()

	defer panichandler.Http(ctx, w)

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
