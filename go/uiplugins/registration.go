package uiplugins

// The registry of the admin UI plugins: one row per plugin in the chi_cache
// table of the PacketFence database. A plugin registers itself when it is
// ready and deregisters itself when it stops, through these accessors or the
// same ones in Perl (pf::ui_plugins): the database credentials stay in the
// PacketFence configuration, the plugin never handles them.
//
//	key         ui_plugins::<name>
//	value       {"name":"<name>","host":"<host>","port":<port>}
//	expires_at  NULL, the row stays until it is deregistered
//
// A plugin that crashes without deregistering stays listed: its manifest
// cannot be fetched, so the admin UI leaves it out, its pages answer 502.

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"regexp"
	"strconv"
	"strings"

	"github.com/inverse-inc/packetfence/go/db"
)

// KeyPrefix is the prefix of the chi_cache keys of the registrations
const KeyPrefix = "ui_plugins::"

// ManifestPath is where a plugin serves its manifest
const ManifestPath = "/manifest.json"

// keep in sync with $NAME_RE in lib/pf/ui_plugins.pm
var nameRe = regexp.MustCompile(`^[a-z][a-z0-9_-]{0,62}$`)

// keep in sync with $HOST_RE in lib/pf/ui_plugins.pm: a hostname (RFC 1123)
var hostRe = regexp.MustCompile(`^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$`)

// Registration tells core how to reach a plugin service: its manifest is at
// <scheme>://<host>:<port>/manifest.json and /api/v1/plugin/<name>/<path> is
// proxied to <scheme>://<host>:<port>/<path>.
//
// The scheme follows the host: http for a loopback host (127.0.0.0/8, ::1,
// localhost: the same host or pod, no network in between), https otherwise,
// with a certificate valid for the host (see RootCAs).
type Registration struct {
	Name string `json:"name"`
	Host string `json:"host"`
	Port int    `json:"port"`
}

// IsLoopback tells if a host is the loopback of the host or pod core runs on
func IsLoopback(host string) bool {
	if strings.EqualFold(host, "localhost") {
		return true
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}

// plainHTTP tells if a plugin is reached over plain HTTP, a variable for the
// tests
var plainHTTP = IsLoopback

// Scheme is http for a loopback host, https otherwise
func (r Registration) Scheme() string {
	if plainHTTP(r.Host) {
		return "http"
	}
	return "https"
}

// BaseURL is the URL the plugin service is reached at
func (r Registration) BaseURL() string {
	return r.Scheme() + "://" + net.JoinHostPort(r.Host, strconv.Itoa(r.Port))
}

// ManifestURL is the URL of the plugin manifest
func (r Registration) ManifestURL() string {
	return r.BaseURL() + ManifestPath
}

// Validate checks a registration without writing it, the same rules as
// pf::ui_plugins::validate:
//   - name: ^[a-z][a-z0-9_-]{0,62}$ (a URL segment)
//   - host: a hostname or an IP address
//   - port: 1 to 65535
func (r Registration) Validate() error {
	if !nameRe.MatchString(r.Name) {
		return fmt.Errorf("invalid name %q", r.Name)
	}
	if net.ParseIP(r.Host) == nil && (len(r.Host) > 253 || !hostRe.MatchString(r.Host)) {
		return fmt.Errorf("invalid host %q", r.Host)
	}
	if r.Port < 1 || r.Port > 65535 {
		return fmt.Errorf("invalid port %d", r.Port)
	}
	return nil
}

// the LIKE pattern of the keys, _ is a wildcard of LIKE
var keyLike = strings.ReplaceAll(KeyPrefix, "_", `\_`) + "%"

// RegisterDB adds or replaces the registration of a plugin in database
func RegisterDB(ctx context.Context, database *sql.DB, r Registration) error {
	if err := r.Validate(); err != nil {
		return err
	}
	data, err := json.Marshal(r)
	if err != nil {
		return err
	}
	_, err = database.ExecContext(ctx,
		"INSERT INTO chi_cache (`key`, `value`, `expires_at`) VALUES (?, ?, NULL) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`), `expires_at` = NULL",
		KeyPrefix+r.Name, data)
	if err != nil {
		return fmt.Errorf("unable to register the UI plugin %s: %w", r.Name, err)
	}
	return nil
}

// DeregisterDB removes the registration of a plugin from database, an unknown
// name is not an error
func DeregisterDB(ctx context.Context, database *sql.DB, name string) error {
	if _, err := database.ExecContext(ctx, "DELETE FROM chi_cache WHERE `key` = ?", KeyPrefix+name); err != nil {
		return fmt.Errorf("unable to deregister the UI plugin %s: %w", name, err)
	}
	return nil
}

// the properties of a stored registration, exactly
var registrationKeys = map[string]bool{"name": true, "host": true, "port": true}

// decodeStrict decodes a stored registration: exactly the keys name, host and
// port, each once, with their exact case (encoding/json alone matches the keys
// case-insensitively and keeps the last of duplicates)
func decodeStrict(value []byte) (Registration, error) {
	r := Registration{}
	raw := map[string]json.RawMessage{}
	d := json.NewDecoder(bytes.NewReader(value))
	if t, err := d.Token(); err != nil || t != json.Delim('{') {
		return r, errors.New("not an object")
	}
	for d.More() {
		t, err := d.Token()
		if err != nil {
			return r, err
		}
		key := t.(string)
		if !registrationKeys[key] {
			return r, fmt.Errorf("unknown property %q", key)
		}
		if _, dup := raw[key]; dup {
			return r, fmt.Errorf("property %q set twice", key)
		}
		var v json.RawMessage
		if err := d.Decode(&v); err != nil {
			return r, err
		}
		raw[key] = v
	}
	if _, err := d.Token(); err != nil {
		return r, err
	}
	if d.More() {
		return r, errors.New("trailing data")
	}
	if len(raw) != len(registrationKeys) {
		return r, errors.New("name, host and port are required")
	}
	if err := json.Unmarshal(raw["name"], &r.Name); err != nil {
		return r, fmt.Errorf("name: %w", err)
	}
	if err := json.Unmarshal(raw["host"], &r.Host); err != nil {
		return r, fmt.Errorf("host: %w", err)
	}
	if err := json.Unmarshal(raw["port"], &r.Port); err != nil {
		return r, fmt.Errorf("port: %w", err)
	}
	return r, nil
}

func decodeRegistration(key string, value []byte) (Registration, error) {
	r, err := decodeStrict(value)
	if err != nil {
		return r, fmt.Errorf("invalid registration %s: %w", key, err)
	}
	if KeyPrefix+r.Name != key {
		return r, fmt.Errorf("invalid registration %s: name %q", key, r.Name)
	}
	if err := r.Validate(); err != nil {
		return r, fmt.Errorf("invalid registration %s: %w", key, err)
	}
	return r, nil
}

// GetDB returns the registration of a plugin, nil when it is not registered
func GetDB(ctx context.Context, database *sql.DB, name string) (*Registration, error) {
	var value []byte
	err := database.QueryRowContext(ctx, "SELECT `value` FROM chi_cache WHERE `key` = ?", KeyPrefix+name).Scan(&value)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	r, err := decodeRegistration(KeyPrefix+name, value)
	if err != nil {
		return nil, err
	}
	return &r, nil
}

// ListDB returns the valid registrations by name. An invalid row is skipped
// and passed to invalid when it is not nil.
func ListDB(ctx context.Context, database *sql.DB, invalid func(error)) (map[string]Registration, error) {
	rows, err := database.QueryContext(ctx, "SELECT `key`, `value` FROM chi_cache WHERE `key` LIKE ?", keyLike)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	registrations := map[string]Registration{}
	for rows.Next() {
		var key string
		var value []byte
		if err := rows.Scan(&key, &value); err != nil {
			return nil, err
		}
		r, err := decodeRegistration(key, value)
		if err != nil {
			if invalid != nil {
				invalid(err)
			}
			continue
		}
		registrations[r.Name] = r
	}
	return registrations, rows.Err()
}

// the database of the PacketFence configuration
func pfDB(ctx context.Context) (*sql.DB, error) {
	return db.DbFromConfig(ctx)
}

// Register adds or replaces the registration of a plugin: call it once the
// plugin serves its manifest. The PacketFence database is used, its
// credentials come from the PacketFence configuration.
func Register(ctx context.Context, r Registration) error {
	database, err := pfDB(ctx)
	if err != nil {
		return err
	}
	defer database.Close()
	return RegisterDB(ctx, database, r)
}

// Deregister removes the registration of a plugin: call it when the plugin
// stops. An unknown name is not an error.
func Deregister(ctx context.Context, name string) error {
	database, err := pfDB(ctx)
	if err != nil {
		return err
	}
	defer database.Close()
	return DeregisterDB(ctx, database, name)
}

// Get returns the registration of a plugin, nil when it is not registered
func Get(ctx context.Context, name string) (*Registration, error) {
	database, err := pfDB(ctx)
	if err != nil {
		return nil, err
	}
	defer database.Close()
	return GetDB(ctx, database, name)
}

// List returns the valid registrations by name, invalid rows are skipped
func List(ctx context.Context) (map[string]Registration, error) {
	database, err := pfDB(ctx)
	if err != nil {
		return nil, err
	}
	defer database.Close()
	return ListDB(ctx, database, nil)
}
