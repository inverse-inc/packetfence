package aaa

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/inverse-inc/packetfence/go/log"
)

var apiPrefix = "/api/v1"
var configApiPrefix = apiPrefix + "/config"

var pathAdminRolesMap = map[string]string{
	configApiPrefix + "/admin_role":  "ADMIN_ROLES",
	configApiPrefix + "/admin_roles": "ADMIN_ROLES",

	configApiPrefix + "/bases": "CONFIGURATION_MAIN",
	configApiPrefix + "/base":  "CONFIGURATION_MAIN",

	configApiPrefix + "/billing_tiers": "BILLING_TIER",
	configApiPrefix + "/billing_tier":  "BILLING_TIER",

	configApiPrefix + "/connection_profiles": "CONNECTION_PROFILES",
	configApiPrefix + "/connection_profile":  "CONNECTION_PROFILES",

	configApiPrefix + "/device_registrations": "DEVICE_REGISTRATION",
	configApiPrefix + "/device_registration":  "DEVICE_REGISTRATION",

	configApiPrefix + "/domains": "DOMAIN",
	configApiPrefix + "/domain":  "DOMAIN",

	configApiPrefix + "/firewalls": "FIREWALL_SSO",
	configApiPrefix + "/firewall":  "FIREWALL_SSO",

	configApiPrefix + "/floating_devices": "FLOATING_DEVICES",
	configApiPrefix + "/floating_device":  "FLOATING_DEVICES",

	configApiPrefix + "/admin_role":  "",
	configApiPrefix + "/admin_roles": "",

	configApiPrefix + "/base":  "",
	configApiPrefix + "/bases": "",

	configApiPrefix + "/billing_tier":  "",
	configApiPrefix + "/billing_tiers": "",

	configApiPrefix + "/connection_profile":  "",
	configApiPrefix + "/connection_profiles": "",

	configApiPrefix + "/device_registration":  "",
	configApiPrefix + "/device_registrations": "",

	configApiPrefix + "/domain":  "",
	configApiPrefix + "/domains": "",

	configApiPrefix + "/firewall":  "",
	configApiPrefix + "/firewalls": "",

	configApiPrefix + "/floating_device":  "",
	configApiPrefix + "/floating_devices": "",

	configApiPrefix + "/maintenance_task":  "PFMON",
	configApiPrefix + "/maintenance_tasks": "PFMON",

	configApiPrefix + "/pki_provider":  "PKI_PROVIDER",
	configApiPrefix + "/pki_providers": "PKI_PROVIDER",

	configApiPrefix + "/portal_module":  "PORTAL_MODULE",
	configApiPrefix + "/portal_modules": "PORTAL_MODULE",

	configApiPrefix + "/realm":  "REALM",
	configApiPrefix + "/realms": "REALM",

	configApiPrefix + "/role":  "USERS_ROLES",
	configApiPrefix + "/roles": "USERS_ROLES",

	configApiPrefix + "/scans": "SCAN",
	configApiPrefix + "/scan":  "SCAN",

	configApiPrefix + "/sources": "USERS_SOURCES",
	configApiPrefix + "/source":  "USERS_SOURCES",

	configApiPrefix + "/switches": "SWITCHES",
	configApiPrefix + "/switch":   "SWITCHES",

	configApiPrefix + "/switch_groups": "SWITCHES",
	configApiPrefix + "/switch_group":  "SWITCHES",

	configApiPrefix + "/syslog_parsers": "PFDETECT",
	configApiPrefix + "/syslog_parser":  "PFDETECT",

	configApiPrefix + "/traffic_shaping_policies": "TRAFFIC_SHAPING",
	configApiPrefix + "/traffic_shaping_policy":   "TRAFFIC_SHAPING",

	configApiPrefix + "/violations": "VIOLATIONS",
	configApiPrefix + "/violation":  "VIOLATIONS",

	apiPrefix + "/endpoints": "NODES",
	apiPrefix + "/users":     "USERS",
}

var methodSuffixMap = map[string]string{
	"GET":    "_READ",
	"POST":   "_CREATE",
	"PUT":    "_UPDATE",
	"PATCH":  "_UPDATE",
	"DELETE": "_DELETE",
}

type TokenAuthorizationMiddleware struct {
	tokenBackend TokenBackend
}

func NewTokenAuthorizationMiddleware(tb TokenBackend) *TokenAuthorizationMiddleware {
	return &TokenAuthorizationMiddleware{
		tokenBackend: tb,
	}
}

func (tam *TokenAuthorizationMiddleware) TokenFromBearerRequest(ctx context.Context, r *http.Request) string {
	authHeader := r.Header.Get("Authorization")
	token := strings.TrimPrefix(authHeader, "Bearer ")

	return token
}

// Checks whether or not that request is authorized based on the path and method
// It will extract the token out of the Authorization header and call the appropriate method
func (tam *TokenAuthorizationMiddleware) BearerRequestIsAuthorized(ctx context.Context, r *http.Request) (bool, error) {
	token := tam.TokenFromBearerRequest(ctx, r)
	xptid := r.Header.Get("X-PacketFence-Tenant-Id")

	tokenInfo := tam.tokenBackend.TokenInfoForToken(token)

	if tokenInfo == nil {
		return false, errors.New("Invalid token info")
	}

	var tenantId int

	if tokenInfo.TenantId == AccessAllTenants && xptid == "" {
		log.LoggerWContext(ctx).Debug("Token wasn't issued for a particular tenant and no X-PacketFence-Tenant-Id was provided. Request will use the default PacketFence tenant")
	} else if xptid == "" {
		log.LoggerWContext(ctx).Debug("Empty X-PacketFence-Tenant-Id, defaulting to token tenant ID")
		tenantId = tokenInfo.TenantId
		r.Header.Set("X-PacketFence-Tenant-Id", strconv.Itoa(tenantId))
	} else {
		var err error
		tenantId, err = strconv.Atoi(xptid)
		if err != nil {
			msg := fmt.Sprintf("Impossible to parse X-PacketFence-Tenant-Id %s into a valid number, error: %s", xptid, err)
			log.LoggerWContext(ctx).Warn(msg)
			return false, errors.New(msg)
		}
	}

	return tam.IsAuthorized(ctx, r.Method, r.URL.Path, tenantId, tokenInfo)
}

// Checks whether or not that request is authorized based on the path and method
func (tam *TokenAuthorizationMiddleware) IsAuthorized(ctx context.Context, method, path string, tenantId int, tokenInfo *TokenInfo) (bool, error) {
	if tokenInfo == nil {
		return false, errors.New("Invalid token info")
	}

	authAdminRoles, err := tam.isAuthorizedAdminRoles(ctx, method, path, tokenInfo.AdminRoles)
	if !authAdminRoles || err != nil {
		return authAdminRoles, err
	}

	authTenant, err := tam.isAuthorizedTenantId(ctx, tenantId, tokenInfo.TenantId)
	if !authTenant || err != nil {
		return authTenant, err
	}

	// If we're here, then we passed all the tests above and we're good to go
	return true, nil
}

func (tam *TokenAuthorizationMiddleware) isAuthorizedTenantId(ctx context.Context, requestTenantId, tokenTenantId int) (bool, error) {
	// Token doesn't have access to any tenant
	if tokenTenantId == AccessNoTenants {
		return false, errors.New("Token is prohibited from accessing data from any tenant")
	} else if tokenTenantId == AccessAllTenants {
		return true, nil
	} else if requestTenantId == tokenTenantId {
		return true, nil
	} else {
		return false, errors.New(
			fmt.Sprintf(
				"Token is not allowed to access this tenant %d and only has access to tenant %d",
				requestTenantId,
				tokenTenantId,
			),
		)
	}
}

func (tam *TokenAuthorizationMiddleware) isAuthorizedAdminRoles(ctx context.Context, method, path string, roles map[string]bool) (bool, error) {
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

func (tam *TokenAuthorizationMiddleware) GetTokenInfoFromBearerRequest(ctx context.Context, r *http.Request) *TokenInfo {
	token := tam.TokenFromBearerRequest(ctx, r)
	return tam.GetTokenInfo(ctx, token)
}

func (tam *TokenAuthorizationMiddleware) GetTokenInfo(ctx context.Context, token string) *TokenInfo {
	return tam.tokenBackend.TokenInfoForToken(token)
}
