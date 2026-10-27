package aaa

import (
	"context"
	"encoding/json"
	"io/ioutil"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/inverse-inc/go-utils/sharedutils"
)

// Admin SSO tokens are 32 random bytes in hex (see RootSSO.pm)
var portalTokenRegexp = regexp.MustCompile(`^[0-9a-f]{64}$`)

type PortalAuthenticationBackend struct {
	PfAuthenticationBackend
}

type PortalAuthenticationReply struct {
	AccessLevel string `json:"access_level"`
	Username    string `json:"pid"`
}

func NewPortalAuthenticationBackend(ctx context.Context, url *url.URL, checkCert bool) *PortalAuthenticationBackend {
	pab := PortalAuthenticationBackend{}
	pab.PfAuthenticationBackend = *(NewPfAuthenticationBackend(ctx, url, checkCert))
	return &pab
}

func (pab *PortalAuthenticationBackend) Authenticate(ctx context.Context, username, password string) (bool, *TokenInfo, error) {
	// The admin UI sends the SSO token without a username.
	// Anything else is a username/password login for the next backends and must never reach the portal.
	if username != "" || !portalTokenRegexp.MatchString(password) {
		return false, nil, nil
	}

	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	// The token goes in a header so it isn't written to the portal access log
	req, err := http.NewRequestWithContext(ctx, "GET", pab.url.String(), nil)
	sharedutils.CheckError(err)
	req.Header.Set("Authorization", "Bearer "+password)
	req.Header.Set("X-Forwarded-For-PacketFence", "127.0.0.1")
	resp, err := pab.httpClient.Do(req)
	if err != nil {
		return false, nil, err
	}

	// Token doesn't exist or is expired
	if resp.StatusCode != http.StatusOK {
		return false, nil, nil
	}

	defer resp.Body.Close()
	reply := PortalAuthenticationReply{}

	respBody, err := ioutil.ReadAll(resp.Body)
	sharedutils.CheckError(err)

	err = json.Unmarshal(respBody, &reply)
	if err != nil {
		return false, nil, err
	}

	// The portal must have granted an access level (no administration rule matched otherwise)
	accessLevel := strings.TrimSpace(reply.AccessLevel)
	if accessLevel == "" || accessLevel == "NONE" {
		return false, nil, nil
	}

	ti := pab.buildTokenInfo(ctx, &reply)

	return true, ti, nil
}

func (pab *PortalAuthenticationBackend) buildTokenInfo(ctx context.Context, data *PortalAuthenticationReply) *TokenInfo {
	adminRolesMap := make(map[string]bool)

	for _, role := range strings.Split(data.AccessLevel, ",") {
		// Trim it of any leading or suffix spaces
		role = strings.Trim(role, " ")
		adminRolesMap[role] = true
	}

	return &TokenInfo{AdminRoles: adminRolesMap, Username: data.Username}
}
