package aaa

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/inverse-inc/packetfence/go/log"
)

var apiPrefix = "/api/v1"
var configApiPrefix = apiPrefix + "/config"
var configNamespaceRe = regexp.MustCompile("^" + regexp.QuoteMeta(configApiPrefix))

type adminRoleMapping struct {
	prefix                   string
	base                     string
	allowedActionsForMethods map[string][]string
}

func (mapping *adminRoleMapping) IsAllowed(method, path string, roles map[string]bool) error {
	if mapping.base == ALLOW_ANY {
		return nil
	}

	// Handle special case for search
	if method == "POST" && strings.HasSuffix(path, "/search") {
		action := mapping.base + "_READ"
		if _, ok := roles[action]; ok {
			return nil
		}
	}

	if actions, found := mapping.allowedActionsForMethods[method]; found {
		for _, action := range actions {
			if _, ok := roles[action]; ok {
				return nil
			}
		}
	}

	msg := fmt.Sprintf("Unauthorized access, lacking the administrative role to access %s for %s", path, method)
	return errors.New(msg)
}

const ALLOW_ANY = "*"

func makeStdAdminRoleMapping(prefix, base string, readonly_bases ...string) adminRoleMapping {
	mapping := adminRoleMapping{
		prefix: prefix,
		base:   base,
		allowedActionsForMethods: map[string][]string{
			"GET":     {base + "_READ"},
			"OPTIONS": {base + "_READ"},
			"POST":    {base + "_CREATE"},
			"PUT":     {base + "_UPDATE"},
			"PATCH":   {base + "_UPDATE"},
			"DELETE":  {base + "_DELETE"},
		},
	}

	for _, readonly_base := range readonly_bases {
		mapping.allowedActionsForMethods["GET"] = append(mapping.allowedActionsForMethods["GET"], readonly_base+"_READ")
	}

	return mapping

}

var systemAdminRoleMapping = makeStdAdminRoleMapping("", "SYSTEM")

var pathAdminRolesMap = []adminRoleMapping{
	makeStdAdminRoleMapping(apiPrefix+"/preference/", ALLOW_ANY),
	makeStdAdminRoleMapping(apiPrefix+"/preferences", ALLOW_ANY),

	makeStdAdminRoleMapping(apiPrefix+"/auth_log/", "NODES"),
	makeStdAdminRoleMapping(apiPrefix+"/auth_logs", "NODES"),
	makeStdAdminRoleMapping(apiPrefix+"/class/", "SECURITY_EVENTS"),
	makeStdAdminRoleMapping(apiPrefix+"/classes", "SECURITY_EVENTS"),
	makeStdAdminRoleMapping(apiPrefix+"/ip4log/", "NODES"),
	makeStdAdminRoleMapping(apiPrefix+"/ip4logs", "NODES"),
	makeStdAdminRoleMapping(apiPrefix+"/ip6log/", "NODES"),
	makeStdAdminRoleMapping(apiPrefix+"/ip6logs", "NODES"),
	makeStdAdminRoleMapping(apiPrefix+"/locationlog/", "NODES"),
	makeStdAdminRoleMapping(apiPrefix+"/locationlogs", "NODES"),
	makeStdAdminRoleMapping(apiPrefix+"/node/", "NODES"),
	makeStdAdminRoleMapping(apiPrefix+"/nodes", "NODES"),
	makeStdAdminRoleMapping(apiPrefix+"/node_categories", "NODES"),
	makeStdAdminRoleMapping(apiPrefix+"/node_category/", "NODES"),
	makeStdAdminRoleMapping(apiPrefix+"/security_event/", "SECURITY_EVENTS"),
	makeStdAdminRoleMapping(apiPrefix+"/security_events", "SECURITY_EVENTS"),
	makeStdAdminRoleMapping(apiPrefix+"/user/", "USERS"),
	makeStdAdminRoleMapping(apiPrefix+"/users", "USERS"),

	makeStdAdminRoleMapping(apiPrefix+"/fingerbank", "FINGERBANK"),

	makeStdAdminRoleMapping(apiPrefix+"/service/", "SERVICES"),
	makeStdAdminRoleMapping(apiPrefix+"/services", "SERVICES"),

	makeStdAdminRoleMapping(apiPrefix+"/reports/", "REPORTS"),
	makeStdAdminRoleMapping(apiPrefix+"/dynamic_reports", "REPORTS"),
	makeStdAdminRoleMapping(apiPrefix+"/dynamic_report/", "REPORTS"),
	makeStdAdminRoleMapping(apiPrefix+"/radius_audit_log/", "RADIUS_LOG"),
	makeStdAdminRoleMapping(apiPrefix+"/dhcp_option82s", "DHCP_OPTION_82"),
	makeStdAdminRoleMapping(apiPrefix+"/dhcp_option82/", "DHCP_OPTION_82"),
	makeStdAdminRoleMapping(apiPrefix+"/radius_audit_logs", "RADIUS_LOG"),

	makeStdAdminRoleMapping(configApiPrefix+"/admin_role/", "ADMIN_ROLES"),
	makeStdAdminRoleMapping(configApiPrefix+"/admin_roles", "ADMIN_ROLES", "NODES", "USERS", "USERS_SOURCES"),
	makeStdAdminRoleMapping(configApiPrefix+"/base/", "CONFIGURATION_MAIN"),
	makeStdAdminRoleMapping(configApiPrefix+"/bases", "CONFIGURATION_MAIN"),
	makeStdAdminRoleMapping(configApiPrefix+"/billing_tier/", "BILLING_TIER"),
	makeStdAdminRoleMapping(configApiPrefix+"/billing_tiers", "BILLING_TIER"),
	makeStdAdminRoleMapping(configApiPrefix+"/certificate/", "CONFIGURATION_MAIN"),
	makeStdAdminRoleMapping(configApiPrefix+"/certificates", "CONFIGURATION_MAIN"),
	makeStdAdminRoleMapping(configApiPrefix+"/checkup", ALLOW_ANY),
	makeStdAdminRoleMapping(configApiPrefix+"/cluster_status", "SERVICES"),
	makeStdAdminRoleMapping(configApiPrefix+"/connection_profile/", "CONNECTION_PROFILES"),
	makeStdAdminRoleMapping(configApiPrefix+"/connection_profiles", "CONNECTION_PROFILES"),
	makeStdAdminRoleMapping(configApiPrefix+"/device_registration/", "DEVICE_REGISTRATION"),
	makeStdAdminRoleMapping(configApiPrefix+"/device_registrations", "DEVICE_REGISTRATION"),
	makeStdAdminRoleMapping(configApiPrefix+"/domain/", "DOMAIN"),
	makeStdAdminRoleMapping(configApiPrefix+"/domains", "DOMAIN"),
	makeStdAdminRoleMapping(configApiPrefix+"/fingerbank_setting/", "FINGERBANK"),
	makeStdAdminRoleMapping(configApiPrefix+"/fingerbank_settings", "FINGERBANK"),
	makeStdAdminRoleMapping(configApiPrefix+"/firewall/", "FIREWALL_SSO"),
	makeStdAdminRoleMapping(configApiPrefix+"/firewalls", "FIREWALL_SSO"),
	makeStdAdminRoleMapping(configApiPrefix+"/floating_device/", "FLOATING_DEVICES"),
	makeStdAdminRoleMapping(configApiPrefix+"/floating_devices", "FLOATING_DEVICES"),
	makeStdAdminRoleMapping(configApiPrefix+"/interface/", "INTERFACES"),
	makeStdAdminRoleMapping(configApiPrefix+"/interfaces", "INTERFACES"),
	makeStdAdminRoleMapping(configApiPrefix+"/l2_network/", "INTERFACES"),
	makeStdAdminRoleMapping(configApiPrefix+"/l2_networks", "INTERFACES"),
	makeStdAdminRoleMapping(configApiPrefix+"/maintenance_task/", "PFMON"),
	makeStdAdminRoleMapping(configApiPrefix+"/maintenance_tasks", "PFMON"),
	makeStdAdminRoleMapping(configApiPrefix+"/pki_provider/", "PKI_PROVIDER"),
	makeStdAdminRoleMapping(configApiPrefix+"/pki_providers", "PKI_PROVIDER"),
	makeStdAdminRoleMapping(configApiPrefix+"/portal_module/", "PORTAL_MODULE"),
	makeStdAdminRoleMapping(configApiPrefix+"/portal_modules", "PORTAL_MODULE"),
	makeStdAdminRoleMapping(configApiPrefix+"/provisioning", "PROVISIONING"),
	makeStdAdminRoleMapping(configApiPrefix+"/provisionings/", "PROVISIONING"),
	makeStdAdminRoleMapping(configApiPrefix+"/realm/", "REALM"),
	makeStdAdminRoleMapping(configApiPrefix+"/realms", "REALM"),
	makeStdAdminRoleMapping(configApiPrefix+"/role/", "USERS_ROLES"),
	makeStdAdminRoleMapping(configApiPrefix+"/roles", "USERS_ROLES"),
	makeStdAdminRoleMapping(configApiPrefix+"/routed_network/", "INTERFACES"),
	makeStdAdminRoleMapping(configApiPrefix+"/routed_networks", "INTERFACES"),
	makeStdAdminRoleMapping(configApiPrefix+"/scan/", "SCAN"),
	makeStdAdminRoleMapping(configApiPrefix+"/scans", "SCAN"),
	makeStdAdminRoleMapping(configApiPrefix+"/security_event/", "SECURITY_EVENTS"),
	makeStdAdminRoleMapping(configApiPrefix+"/security_events", "SECURITY_EVENTS"),
	makeStdAdminRoleMapping(configApiPrefix+"/source/", "USERS_SOURCES"),
	makeStdAdminRoleMapping(configApiPrefix+"/sources", "USERS_SOURCES"),
	makeStdAdminRoleMapping(configApiPrefix+"/switch/", "SWITCHES"),
	makeStdAdminRoleMapping(configApiPrefix+"/switch_group/", "SWITCHES"),
	makeStdAdminRoleMapping(configApiPrefix+"/switch_groups", "SWITCHES"),
	makeStdAdminRoleMapping(configApiPrefix+"/switches", "SWITCHES"),
	makeStdAdminRoleMapping(configApiPrefix+"/syslog_forwarder/", "SYSLOG"),
	makeStdAdminRoleMapping(configApiPrefix+"/syslog_forwarders", "SYSLOG"),
	makeStdAdminRoleMapping(configApiPrefix+"/syslog_parser/", "PFDETECT"),
	makeStdAdminRoleMapping(configApiPrefix+"/syslog_parsers", "PFDETECT"),
	makeStdAdminRoleMapping(configApiPrefix+"/traffic_shaping_policies", "TRAFFIC_SHAPING"),
	makeStdAdminRoleMapping(configApiPrefix+"/traffic_shaping_policy/", "TRAFFIC_SHAPING"),
	makeStdAdminRoleMapping(configApiPrefix+"/wmi_rule/", "WMI"),
	makeStdAdminRoleMapping(configApiPrefix+"/wmi_rules", "WMI"),
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

	tokenInfo, _ := tam.tokenBackend.TokenInfoForToken(token)

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
	var roleMapping adminRoleMapping
	found := false
	for _, o := range pathAdminRolesMap {
		if strings.HasPrefix(path, o.prefix) && o.base != "" {
			roleMapping = o
			found = true
			break
		}
	}

	// If not found, use default
	if found == false {
		log.LoggerWContext(ctx).Debug(fmt.Sprintf("Can't find admin role for path %s, using SYSTEM", path))
		roleMapping = systemAdminRoleMapping
	}

	if err := roleMapping.IsAllowed(method, path, roles); err != nil {
		log.LoggerWContext(ctx).Debug(err.Error())
		return false, err
	}

	return true, nil
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

func (tam *TokenAuthorizationMiddleware) GetTokenInfoFromBearerRequest(ctx context.Context, r *http.Request) (*TokenInfo, time.Time) {
	token := tam.TokenFromBearerRequest(ctx, r)
	return tam.GetTokenInfo(ctx, token)
}

func (tam *TokenAuthorizationMiddleware) GetTokenInfo(ctx context.Context, token string) (*TokenInfo, time.Time) {
	return tam.tokenBackend.TokenInfoForToken(token)
}
