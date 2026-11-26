package maint

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net"
	"net/netip"
	"sort"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/mac"
	"github.com/smallstep/nosql/database"
)

var AnyPrefix = netip.MustParsePrefix("0.0.0.0/0")

func ParseAcl(acl string) (Matcher, error) {
	str := strings.TrimSpace(acl)
	//Remove comment
	if len(str) > 1 {
		if i := strings.IndexRune(str[1:], '#'); i >= 0 {
			str = str[:i+1]
		}
	}
	parts := strings.Fields(str)
	if len(parts) == 0 {
		return Matcher{}, fmt.Errorf("Invalid Syntax: '%s'", acl)
	}

	i := 0
	matcher := Matcher{}
	hasDstMac := false
	switch parts[i] {
	default:
		return Matcher{}, fmt.Errorf("Invalid Action: '%s'", acl)
	case "permit", "deny":
		matcher.Action = parts[i]
	case "#permit", "#deny":
		matcher.Action = parts[i][1:]
		hasDstMac = true
	}

	i++
	if i >= len(parts) {
		return Matcher{}, fmt.Errorf("Invalid Syntax: '%s'", acl)
	}

	switch parts[i] {
	default:
		return Matcher{}, fmt.Errorf("Invalid Proto: '%s'", acl)
	case "tcp", "udp", "icmp":
		matcher.Proto = IpProtocol(parts[i])
	}

	i++
	if i >= len(parts) {
		return Matcher{}, fmt.Errorf("Invalid Syntax: '%s'", acl)
	}
	if parts[i] != "any" {
		return Matcher{}, fmt.Errorf("Invalid Src Address: '%s'", acl)
	}

	matcher.SrcNet = AnyPrefix
	i++
	if i >= len(parts) {
		return Matcher{}, fmt.Errorf("Invalid Syntax: '%s'", acl)
	}

	switch parts[i] {
	default:

		ip, err := netip.ParseAddr(parts[i])
		if err != nil {
			return Matcher{}, fmt.Errorf("Invalid Dst Address '%s': %w", acl, err)
		}

		i++
		if i >= len(parts) {
			return Matcher{}, fmt.Errorf("Invalid Syntax: '%s'", acl)
		}
		mask, err := netip.ParseAddr(parts[i])
		if err != nil {
			return Matcher{}, fmt.Errorf("Invalid Dst Address '%s': %w", acl, err)
		}

		if !mask.Is4() {
			return Matcher{}, fmt.Errorf("Invalid Dst Wildcard Invalid Syntax: '%s'", acl)
		}

		mask4 := mask.As4()
		for i, b := range mask4 {
			mask4[i] = ^b
		}

		one, _ := net.IPv4Mask(mask4[0], mask4[1], mask4[2], mask4[3]).Size()
		matcher.DstNet = netip.PrefixFrom(ip, one)
	case "any":
		matcher.DstNet = AnyPrefix
	case "host":
		i++
		if i >= len(parts) {
			return Matcher{}, fmt.Errorf("Invalid Syntax: '%s'", acl)
		}
		if hasDstMac {
			destMac, err := mac.NewFromString(parts[i])
			if err != nil {
				return Matcher{}, fmt.Errorf("Invalid Dst Mac '%s': %w", acl, err)
			}

			matcher.DstNet = AnyPrefix
			matcher.DstMac = destMac
			break
		}

		p, err := netip.ParsePrefix(parts[i] + "/32")
		if err != nil {
			return Matcher{}, fmt.Errorf("Invalid Dst Address '%s': %w", acl, err)
		}

		matcher.DstNet = p
	}

	i++
	if i < len(parts) {
		switch parts[i] {
		default:
			return Matcher{}, fmt.Errorf("Invalid port operation: '%s'", acl)
		case "eq":
			matcher.Op = parts[i]
			i++
			if i >= len(parts) {
				return Matcher{}, fmt.Errorf("Invalid Syntax: '%s'", acl)
			}
			port, err := strconv.ParseUint(parts[i], 10, 16)
			if err != nil {
				return Matcher{}, fmt.Errorf("Invalid port '%s': %w", acl, err)
			}
			matcher.Port = int(port)
		case "range":
			matcher.Op = parts[i]
			i++
			if i+1 >= len(parts) {
				return Matcher{}, fmt.Errorf("Invalid Syntax: '%s'", acl)
			}
			port, err := strconv.ParseUint(parts[i], 10, 16)
			if err != nil {
				return Matcher{}, fmt.Errorf("Invalid start port '%s': %w", acl, err)
			}
			matcher.Port = int(port)
			port, err = strconv.ParseUint(parts[i+1], 10, 16)
			if err != nil {
				return Matcher{}, fmt.Errorf("Invalid end port '%s': %w", acl, err)
			}
			matcher.EndPort = int(port)
			if matcher.Port > matcher.EndPort {
				return Matcher{}, fmt.Errorf("Invalid port range '%s': start port is greater than end port", acl)
			}
		}
	}

	return matcher, nil
}

type Matcher struct {
	Action  string
	DstMac  mac.Mac
	Op      string
	Proto   IpProtocol
	Port    int
	EndPort int
	SrcNet  netip.Prefix
	DstNet  netip.Prefix
}

func (m *Matcher) Matches(ne *NetworkEvent) bool {
	if m.Action == "deny" {
		return false
	}

	if m.Op == "range" {
		return m.Proto == ne.IpProtocol && m.SrcNet.Contains(ne.SourceIp) && m.matchDest(ne) &&
			(m.Port <= ne.DestPort && ne.DestPort <= m.EndPort)
	}

	return (m.Op == "" || m.Port == ne.DestPort) && m.Proto == ne.IpProtocol && m.SrcNet.Contains(ne.SourceIp) && m.matchDest(ne)
}

func (m *Matcher) matchDest(ne *NetworkEvent) bool {
	if m.DstMac.IsZero() {
		return m.DstNet.Contains(ne.DestIp)
	}

	if ne.DestInventoryitem == nil {
		return false
	}

	if len(ne.DestInventoryitem.ExternalIDS) == 0 {
		return false
	}

	return ne.DestInventoryitem.ExternalIDS[0] == m.DstMac.String()
}

type Policy struct {
	EnforcementInfo []EnforcementInfo `json:"enforcement_info"`
	Acls            []string          `json:"acls"`
	Matchers        []Matcher         `json:"-"`
}

func (p *Policy) UpdateMatchers() {

	matchers := make([]Matcher, 0, len(p.Acls))
	for _, acl := range p.Acls {
		matcher, err := ParseAcl(acl)
		if err != nil {
			log.LogError(context.Background(), "UpdateMatcher ParseAcl error: "+err.Error())
			continue
		}

		matchers = append(matchers, matcher)
	}

	p.Matchers = matchers
}

const RolesPoliciesMapKey = "RolesPoliciesMap"

const RolesPoliciesMapSql = "SELECT value, expires_at FROM chi_cache WHERE `key` = ? AND expires_at != ?"

func UpdatePolicyMap(ctx context.Context, db *sql.DB) {
	ticker := time.NewTicker(time.Second)
	expires_at := float64(0)
	var stmt *sql.Stmt
	var err error
	stmt, err = db.PrepareContext(ctx, RolesPoliciesMapSql)
	for err != nil {
		log.LogError(ctx, "Cannot Prepare Statement: "+err.Error())
		time.Sleep(time.Second * 5)
		stmt, err = db.PrepareContext(ctx, RolesPoliciesMapSql)
	}

	defer stmt.Close()
loop:
	for {
		select {
		case <-ticker.C:
			data := []byte{}
			err = stmt.QueryRowContext(ctx, RolesPoliciesMapKey, expires_at).Scan(&data, &expires_at)
			if err == database.ErrNotFound {
				continue
			}

			if err != nil {
				time.Sleep(time.Second * 10)
				continue
			}

			lookup := &PolicyLookup{}
			err := json.Unmarshal(data, lookup)
			if err != nil {
				log.LogError(ctx, "Cannot UnMarshal PolicyLookup:"+err.Error())
				continue
			}

			lookup.UpdateMatchers()
			StorePolicyLookup(lookup)

		case <-ctx.Done():
			break loop
		}
	}
}

type PolicyLookup struct {
	ByRoles        map[string][]Policy
	NodesPolicies  map[string][]Policy
	ImplictPolices []Policy
}

// Lookup resolves the enforcement info of an event. Implicit policies are
// checked first for any event with a source MAC, then the MAC and role
// policies (see LookupWithRoles).
func (l PolicyLookup) Lookup(ctx context.Context, db *sql.DB, ne *NetworkEvent) *EnforcementInfo {
	srcMac, srcRole := ne.GetSrcRole(ctx, db)
	dstMac, dstRole := ne.GetDstRole(ctx, db)
	return l.lookupResolved(ne, srcMac, srcRole, dstMac, dstRole)
}

// lookupResolved is Lookup once the node roles are known: implicit policies
// first when the event has a source MAC, then LookupWithRoles.
func (l PolicyLookup) lookupResolved(ne *NetworkEvent, srcMac, srcRole, dstMac, dstRole string) *EnforcementInfo {
	if srcMac != "" {
		if ei := l.LookupImplict(ne); ei != nil {
			return ei
		}
	}

	return l.LookupWithRoles(ne, srcMac, srcRole, dstMac, dstRole)
}

// LookupWithRoles resolves the MAC and role enforcement info of an event whose
// node roles were already looked up. The MAC policies of the source then
// destination are checked first, then the role policies of the source then
// destination. MAC policies are authoritative per side: when a node's MAC has
// policies but none match, that node's role policies are not checked, while
// the other node's still are. Implicit policies are not checked here: Lookup
// checks them before calling it.
func (l PolicyLookup) LookupWithRoles(ne *NetworkEvent, srcMac, srcRole, dstMac, dstRole string) *EnforcementInfo {
	var srcFound, dstFound bool
	var ei *EnforcementInfo
	if ei, srcFound = l.LookupByMac(srcMac, ne); ei != nil {
		return ei
	}

	if ei, dstFound = l.LookupByMac(dstMac, ne); ei != nil {
		return ei
	}

	if !srcFound {
		if ei, _ = l.LookupByRoles(srcRole, ne); ei != nil {
			return ei
		}
	}

	if !dstFound {
		if ei, _ = l.LookupByRoles(dstRole, ne); ei != nil {
			return ei
		}
	}

	return nil
}

// LookupByRoles returns the enforcement info of the first policy of role
// matching ne. The boolean is true when role has at least one policy to look
// up, even if none of them matched.
func (l *PolicyLookup) LookupByRoles(role string, ne *NetworkEvent) (*EnforcementInfo, bool) {
	policies, ok := l.ByRoles[role]
	if !ok || len(policies) == 0 {
		return nil, false
	}

	return matchEnforcementInfo(policies, ne), true
}

// LookupByMac returns the enforcement info of the first policy of mac matching
// ne. The boolean is true when mac has at least one policy to look up, even
// if none of them matched: an empty policy list counts as no policies.
func (l *PolicyLookup) LookupByMac(mac string, ne *NetworkEvent) (*EnforcementInfo, bool) {
	policies, ok := l.NodesPolicies[macKey(mac)]
	if !ok || len(policies) == 0 {
		return nil, false
	}

	return matchEnforcementInfo(policies, ne), true
}

func matchEnforcementInfo(policies []Policy, ne *NetworkEvent) *EnforcementInfo {
	for _, policy := range policies {
		for _, match := range policy.Matchers {
			if match.Matches(ne) {
				if len(policy.EnforcementInfo) > 0 {
					return &policy.EnforcementInfo[0]
				}
			}
		}
	}
	return nil
}

func (l *PolicyLookup) LookupImplict(ne *NetworkEvent) *EnforcementInfo {
	return matchEnforcementInfo(l.ImplictPolices, ne)
}

// UpdateMatchers builds the ACL matchers of every policy and normalizes the
// NodesPolicies keys with macKey so LookupByMac ignores the MAC case. Keys
// that only differ by case are merged, their policies appended in sorted key
// order.
func (l *PolicyLookup) UpdateMatchers() {
	l.normalizeNodesPolicies()
	for _, v := range l.ByRoles {
		for i := range v {
			p := &v[i]
			p.UpdateMatchers()
		}
	}

	for _, v := range l.NodesPolicies {
		for i := range v {
			p := &v[i]
			p.UpdateMatchers()
		}
	}

	for i := range l.ImplictPolices {
		p := &l.ImplictPolices[i]
		p.UpdateMatchers()
	}
}

func (l *PolicyLookup) normalizeNodesPolicies() {
	if len(l.NodesPolicies) == 0 {
		return
	}

	keys := make([]string, 0, len(l.NodesPolicies))
	for k := range l.NodesPolicies {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	normalized := make(map[string][]Policy, len(l.NodesPolicies))
	for _, k := range keys {
		nk := macKey(k)
		normalized[nk] = append(normalized[nk], l.NodesPolicies[k]...)
	}
	l.NodesPolicies = normalized
}

// macKey normalizes a MAC for the NodesPolicies map. node.mac is compared
// case-insensitively by MariaDB (utf8mb4_general_ci) but a Go map is not, and
// MACs filled in from ip4log keep whatever case the writer used.
func macKey(mac string) string {
	return strings.ToLower(mac)
}

var storePolicyLookup atomic.Value

func GetPolicyLookup() *PolicyLookup {
	return storePolicyLookup.Load().(*PolicyLookup)
}

func StorePolicyLookup(p *PolicyLookup) {
	storePolicyLookup.Store(p)
}

func UpdateNetworkEvent(ctx context.Context, db *sql.DB, ne *NetworkEvent) {
	lookup := GetPolicyLookup()
	ei := lookup.Lookup(ctx, db, ne)
	if ei != nil {
		ne.EnforcementInfo = ei
	}
}

func init() {
	StorePolicyLookup(&PolicyLookup{})
}
