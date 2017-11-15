package aaa

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/inverse-inc/packetfence/go/log"
)

var configApiPrefix = "/config"

var adminRolesPathMap = map[string]string{
	"ADMIN_ROLES":         configApiPrefix + "/admin_roles",
	"FINGERBANK":          configApiPrefix + "/fingerbank",
	"FIREWALL_SSO":        configApiPrefix + "/firewalls_sso",
	"FLOATING_DEVICES":    configApiPrefix + "/floating_devices",
	"INTERFACES":          configApiPrefix + "/interfaces",
	"CONNECTION_PROFILES": configApiPrefix + "/connection_profiles",
	"PROVISIONING":        configApiPrefix + "/provisioners",
	"SWITCHES":            configApiPrefix + "/switches",
	"USERS_ROLES":         configApiPrefix + "/roles",
	"USERS_SOURCES":       configApiPrefix + "/authentication_sources",
	"VIOLATIONS":          configApiPrefix + "/violations",
	"REALM":               configApiPrefix + "/realms",
	"DOMAIN":              configApiPrefix + "/domains",
	"SCAN":                configApiPrefix + "/scans",
	"WMI":                 configApiPrefix + "/wmi",
	"WRIX":                configApiPrefix + "/wrix",
	"PKI_PROVIDER":        configApiPrefix + "/pki_providers",
	"PFDETECT":            configApiPrefix + "/syslog_parsers",
	"BILLING_TIER":        configApiPrefix + "/billing_tiers",
	"PORTAL_MODULE":       configApiPrefix + "/portal_modules",
	"PFMON":               configApiPrefix + "/maintenance_tasks",
	"DEVICE_REGISTRATION": configApiPrefix + "/device_registration_policies",

	"NODES": "/endpoints",
	"USERS": "/users",
}

// Gets built dynamically in the init and is the reverse of adminRolesPathMap
var pathAdminRolesMap map[string]string

var methodSuffixMap = map[string]string{
	"GET":    "_READ",
	"POST":   "_CREATE",
	"PUT":    "_UPDATE",
	"PATCH":  "_UPDATE",
	"DELETE": "_DELETE",
}

func init() {
	pathAdminRolesMap = make(map[string]string)
	for k, v := range adminRolesPathMap {
		pathAdminRolesMap[v] = k
	}
}

type TokenAuthorizationMiddleware struct {
	tokenBackend TokenBackend
}

func NewTokenAuthorizationMiddleware(tb TokenBackend) *TokenAuthorizationMiddleware {
	return &TokenAuthorizationMiddleware{
		tokenBackend: tb,
	}
}

func (tam *TokenAuthorizationMiddleware) AdminRolesForToken(token string) map[string]bool {
	roles := tam.tokenBackend.AdminRolesForToken(token)
	rolesMap := make(map[string]bool)
	for _, role := range roles {
		rolesMap[role] = true
	}
	return rolesMap
}

// Checks whether or not that request is authorized based on the path and method
// It will extract the token out of the Authorization header and call the appropriate method
func (tam *TokenAuthorizationMiddleware) BearerRequestIsAuthorized(ctx context.Context, r *http.Request) (bool, error) {
	authHeader := r.Header.Get("Authorization")
	token := strings.TrimPrefix(authHeader, "Bearer ")
	adminRoles := tam.AdminRolesForToken(token)
	return tam.IsAuthorized(ctx, r.Method, r.URL.Path, adminRoles)
}

// Checks whether or not that request is authorized based on the path and method
func (tam *TokenAuthorizationMiddleware) IsAuthorized(ctx context.Context, method, path string, roles map[string]bool) (bool, error) {
	baseAdminRole := pathAdminRolesMap[path]

	if baseAdminRole == "" {
		log.LoggerWContext(ctx).Debug(fmt.Sprintf("Can't find admin role for path %s, using SYSTEM", path))
		baseAdminRole = "SYSTEM"
	}

	suffix := methodSuffixMap[method]

	if suffix == "" {
		msg := fmt.Sprintf("Impossible to find admin role suffix for unknown method %s")
		log.LoggerWContext(ctx).Warn(msg)
		return false, errors.New(msg)
	}

	adminRole := baseAdminRole + suffix

	if _, ok := roles[adminRole]; ok {
		log.LoggerWContext(ctx).Debug("Access is authorized for this request")
		return true, nil
	} else {
		msg := fmt.Sprintf("Unauthorized access, lacking the %s administrative role", adminRole)
		log.LoggerWContext(ctx).Debug(msg)
		return false, errors.New(msg)
	}
}
