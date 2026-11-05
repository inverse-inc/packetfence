package uiplugins

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"regexp"
	"strconv"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/redis_cache"
	"github.com/redis/go-redis/v9"
)

// RedisKey is the redis-cache hash of the registrations: field the plugin id,
// value the JSON Registration.
const RedisKey = "pf:ui_plugins"

// Namespace is the pfconfig namespace built from RedisKey, it must be expired
// after every change of RedisKey.
const Namespace = "resource::ui_plugins"

// keep in sync with $ID_RE in lib/pfconfig/namespaces/resource/ui_plugins.pm
var idRe = regexp.MustCompile(`^[a-z][a-z0-9_-]{0,62}$`)

// Registration tells core how to reach the manifest of a plugin service.
type Registration struct {
	ID           string `json:"id"`
	Scheme       string `json:"scheme"`
	Host         string `json:"host"`
	Port         int    `json:"port"`
	ManifestPath string `json:"manifest_path"`
}

// ManifestURL is the URL of the plugin manifest
func (r Registration) ManifestURL() string {
	scheme := r.Scheme
	if scheme == "" {
		scheme = "http"
	}
	return fmt.Sprintf("%s://%s%s", scheme, net.JoinHostPort(r.Host, strconv.Itoa(r.Port)), r.ManifestPath)
}

// Validate checks a registration, the same rules as the pfconfig namespace
func (r Registration) Validate() error {
	if !idRe.MatchString(r.ID) {
		return fmt.Errorf("invalid id %q", r.ID)
	}
	if r.Scheme != "" && r.Scheme != "http" && r.Scheme != "https" {
		return fmt.Errorf("invalid scheme %q", r.Scheme)
	}
	if r.Host == "" {
		return errors.New("missing host")
	}
	if r.Port <= 0 || r.Port > 65535 {
		return fmt.Errorf("invalid port %d", r.Port)
	}
	if len(r.ManifestPath) == 0 || r.ManifestPath[0] != '/' {
		return fmt.Errorf("invalid manifest_path %q", r.ManifestPath)
	}
	return nil
}

// Expirer expires a pfconfig namespace
type Expirer func(ctx context.Context, namespace string) error

// PfconfigExpire expires a namespace through the pfconfig socket
// (PFCONFIG_PROTO, PFCONFIG_TCP_HOST, PFCONFIG_TCP_PORT)
func PfconfigExpire(ctx context.Context, namespace string) error {
	payload, err := json.Marshal(map[string]any{
		"method":    "expire",
		"namespace": namespace,
		"light":     0,
		"encoding":  "json",
	})
	if err != nil {
		return err
	}
	response := struct {
		Status string `json:"status"`
	}{}
	if err := json.Unmarshal(pfconfigdriver.FetchSocket(ctx, string(payload)+"\n"), &response); err != nil {
		return fmt.Errorf("invalid pfconfig answer: %w", err)
	}
	if response.Status != "OK." {
		return fmt.Errorf("pfconfig did not expire %s: %q", namespace, response.Status)
	}
	return nil
}

// Registry registers the plugin services in redis
type Registry struct {
	Redis  *redis.Client
	Expire Expirer
}

// NewRegistry uses the redis-cache (REDIS_CACHE_HOST, REDIS_CACHE_PORT) and
// the pfconfig socket of the environment
func NewRegistry() *Registry {
	return &Registry{Redis: redis_cache.GetClient(), Expire: PfconfigExpire}
}

// Register adds or replaces a plugin registration, call it when the plugin
// service is ready to serve its manifest
func (reg *Registry) Register(ctx context.Context, r Registration) error {
	if r.Scheme == "" {
		r.Scheme = "http"
	}
	if err := r.Validate(); err != nil {
		return err
	}
	data, err := json.Marshal(r)
	if err != nil {
		return err
	}
	if err := reg.Redis.HSet(ctx, RedisKey, r.ID, data).Err(); err != nil {
		return fmt.Errorf("unable to register UI plugin %s: %w", r.ID, err)
	}
	return reg.Expire(ctx, Namespace)
}

// Deregister removes a plugin registration, call it when the plugin service
// stops
func (reg *Registry) Deregister(ctx context.Context, id string) error {
	if err := reg.Redis.HDel(ctx, RedisKey, id).Err(); err != nil {
		return fmt.Errorf("unable to deregister UI plugin %s: %w", id, err)
	}
	return reg.Expire(ctx, Namespace)
}

// Registrations is the pfconfig namespace of the registrations
type Registrations struct {
	pfconfigdriver.StructConfig
	PfconfigMethod          string `val:"element"`
	PfconfigNS              string `val:"resource::ui_plugins"`
	PfconfigDecodeInElement string `val:"yes"`
	Element                 map[string]Registration
}

// LoadRegistrations reads the registrations from pfconfig
func LoadRegistrations(ctx context.Context) (map[string]Registration, error) {
	registrations := Registrations{}
	if err := pfconfigdriver.FetchDecodeSocket(ctx, &registrations); err != nil {
		return nil, err
	}
	if registrations.Element == nil {
		return map[string]Registration{}, nil
	}
	return registrations.Element, nil
}
