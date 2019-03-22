package aaa

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"regexp"
	"strconv"
	"strings"

	"github.com/inverse-inc/packetfence/go/log"
)

var apiPrefix = "/api/v1"
var configApiPrefix = apiPrefix + "/config"
var configNamespaceRe = regexp.MustCompile("^" + regexp.QuoteMeta(configApiPrefix))

type adminRoleMapping struct {
	prefix string
	role   string
}

const ALLOW_ANY = "*"

var pathAdminRolesMap = []adminRoleMapping{
	adminRoleMapping{prefix: apiPrefix + "/preference/", role: ALLOW_ANY},
	adminRoleMapping{prefix: apiPrefix + "/preferences", role: ALLOW_ANY},

	adminRoleMapping{prefix: apiPrefix + "/node/", role: "NODES"},
	adminRoleMapping{prefix: apiPrefix + "/nodes", role: "NODES"},
	adminRoleMapping{prefix: apiPrefix + "/user/", role: "USERS"},
	adminRoleMapping{prefix: apiPrefix + "/users", role: "USERS"},

	adminRoleMapping{prefix: configApiPrefix + "/admin_role/", role: "ADMIN_ROLES"},
	adminRoleMapping{prefix: configApiPrefix + "/admin_roles", role: "ADMIN_ROLES"},
	adminRoleMapping{prefix: configApiPrefix + "/base/", role: "CONFIGURATION_MAIN"},
	adminRoleMapping{prefix: configApiPrefix + "/bases", role: "CONFIGURATION_MAIN"},
	adminRoleMapping{prefix: configApiPrefix + "/billing_tier/", role: "BILLING_TIER"},
	adminRoleMapping{prefix: configApiPrefix + "/billing_tiers", role: "BILLING_TIER"},
	adminRoleMapping{prefix: configApiPrefix + "/interface/", role: "INTERFACES"},
	adminRoleMapping{prefix: configApiPrefix + "/interfaces", role: "INTERFACES"},
	adminRoleMapping{prefix: configApiPrefix + "/connection_profile/", role: "CONNECTION_PROFILES"},
	adminRoleMapping{prefix: configApiPrefix + "/connection_profiles", role: "CONNECTION_PROFILES"},
	adminRoleMapping{prefix: configApiPrefix + "/device_registration/", role: "DEVICE_REGISTRATION"},
	adminRoleMapping{prefix: configApiPrefix + "/device_registrations", role: "DEVICE_REGISTRATION"},
	adminRoleMapping{prefix: configApiPrefix + "/domain/", role: "DOMAIN"},
	adminRoleMapping{prefix: configApiPrefix + "/domains", role: "DOMAIN"},
	adminRoleMapping{prefix: configApiPrefix + "/firewall/", role: "FIREWALL_SSO"},
	adminRoleMapping{prefix: configApiPrefix + "/firewalls", role: "FIREWALL_SSO"},
	adminRoleMapping{prefix: configApiPrefix + "/floating_device/", role: "FLOATING_DEVICES"},
	adminRoleMapping{prefix: configApiPrefix + "/floating_devices", role: "FLOATING_DEVICES"},
	adminRoleMapping{prefix: configApiPrefix + "/maintenance_task/", role: "PFMON"},
	adminRoleMapping{prefix: configApiPrefix + "/maintenance_tasks", role: "PFMON"},
	adminRoleMapping{prefix: configApiPrefix + "/pki_provider/", role: "PKI_PROVIDER"},
	adminRoleMapping{prefix: configApiPrefix + "/pki_providers", role: "PKI_PROVIDER"},
	adminRoleMapping{prefix: configApiPrefix + "/portal_module/", role: "PORTAL_MODULE"},
	adminRoleMapping{prefix: configApiPrefix + "/portal_modules", role: "PORTAL_MODULE"},
	adminRoleMapping{prefix: configApiPrefix + "/realm/", role: "REALM"},
	adminRoleMapping{prefix: configApiPrefix + "/realms", role: "REALM"},
	adminRoleMapping{prefix: configApiPrefix + "/role/", role: "USERS_ROLES"},
	adminRoleMapping{prefix: configApiPrefix + "/roles", role: "USERS_ROLES"},
	adminRoleMapping{prefix: configApiPrefix + "/scan/", role: "SCAN"},
	adminRoleMapping{prefix: configApiPrefix + "/scans", role: "SCAN"},
	adminRoleMapping{prefix: configApiPrefix + "/source/", role: "USERS_SOURCES"},
	adminRoleMapping{prefix: configApiPrefix + "/sources", role: "USERS_SOURCES"},
	adminRoleMapping{prefix: configApiPrefix + "/switch/", role: "SWITCHES"},
	adminRoleMapping{prefix: configApiPrefix + "/switches", role: "SWITCHES"},
	adminRoleMapping{prefix: configApiPrefix + "/switch_group/", role: "SWITCHES"},
	adminRoleMapping{prefix: configApiPrefix + "/switch_groups", role: "SWITCHES"},
	adminRoleMapping{prefix: configApiPrefix + "/syslog_parser/", role: "PFDETECT"},
	adminRoleMapping{prefix: configApiPrefix + "/syslog_parsers", role: "PFDETECT"},
	adminRoleMapping{prefix: configApiPrefix + "/traffic_shaping_policies", role: "TRAFFIC_SHAPING"},
	adminRoleMapping{prefix: configApiPrefix + "/traffic_shaping_policy/", role: "TRAFFIC_SHAPING"},
	adminRoleMapping{prefix: configApiPrefix + "/security_event/", role: "SECURITY_EVENTS"},
	adminRoleMapping{prefix: configApiPrefix + "/security_events", role: "SECURITY_EVENTS"},
}

var methodSuffixMap = map[string]string{
	"GET":     "_READ",
	"OPTIONS": "_READ",
	"POST":    "_CREATE",
	"PUT":     "_UPDATE",
	"PATCH":   "_UPDATE",
	"DELETE":  "_DELETE",
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

	roles := make([]string, len(tokenInfo.AdminRoles))
	i := 0
	for r, _ := range tokenInfo.AdminRoles {
		roles[i] = r
		i++
	}
	r.Header.Set("X-PacketFence-Admin-Roles", strings.Join(roles, ","))

	r.Header.Set("X-PacketFence-Username", tokenInfo.Username)

	return tam.IsAuthorized(ctx, r.Method, r.URL.Path, tenantId, tokenInfo)
}

// Checks whether or not that request is authorized based on the path and method
func (tam *TokenAuthorizationMiddleware) IsAuthorized(ctx context.Context, method, path string, tenantId int, tokenInfo *TokenInfo) (bool, error) {
	if tokenInfo == nil {
		return false, errors.New("Invalid token info")
	}

	authAdminRoles, err := tam.isAuthorizedAdminActions(ctx, method, path, tokenInfo.AdminActions())
	if !authAdminRoles || err != nil {
		return authAdminRoles, err
	}

	authTenant, err := tam.isAuthorizedTenantId(ctx, tenantId, tokenInfo.TenantId)
	if !authTenant || err != nil {
		return authTenant, err
	}

	authConfig, err := tam.isAuthorizedConfigNamespace(ctx, path, tokenInfo.TenantId)
	if !authConfig || err != nil {
		return authConfig, err
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

func (tam *TokenAuthorizationMiddleware) isAuthorizedAdminActions(ctx context.Context, method, path string, roles map[string]bool) (bool, error) {

	var baseAdminRole string
	for _, o := range pathAdminRolesMap {
		base := o.prefix
		role := o.role
		if strings.HasPrefix(path, base) && role != "" {
			baseAdminRole = role
			break
		}
	}

	// If its still empty, then we'll default to SYSTEM
	if baseAdminRole == "" {
		log.LoggerWContext(ctx).Debug(fmt.Sprintf("Can't find admin role for path %s, using SYSTEM", path))
		baseAdminRole = "SYSTEM"
	}

	suffix := methodSuffixMap[method]

	if suffix == "" {
		msg := fmt.Sprintf("Impossible to find admin role suffix for unknown method %s", method)
		log.LoggerWContext(ctx).Warn(msg)
		return false, errors.New(msg)
	}

	if baseAdminRole == ALLOW_ANY {
		return true, nil
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

func (tam *TokenAuthorizationMiddleware) isAuthorizedConfigNamespace(ctx context.Context, path string, tokenTenantId int) (bool, error) {
	// If we're not hitting the config namespace, then there is no need to enforce anything below
	if !configNamespaceRe.MatchString(path) {
		return true, nil
	}

	if tokenTenantId != AccessAllTenants {
		return false, errors.New(fmt.Sprintf("Token is not allowed to access the configuration namespace because it is scoped to a single tenant."))
	} else {
		return true, nil
	}
}

func (tam *TokenAuthorizationMiddleware) GetTokenInfoFromBearerRequest(ctx context.Context, r *http.Request) *TokenInfo {
	token := tam.TokenFromBearerRequest(ctx, r)
	return tam.GetTokenInfo(ctx, token)
}

func (tam *TokenAuthorizationMiddleware) GetTokenInfo(ctx context.Context, token string) *TokenInfo {
	return tam.tokenBackend.TokenInfoForToken(token)
}
