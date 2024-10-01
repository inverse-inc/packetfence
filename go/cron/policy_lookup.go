package maint

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net"
	"net/netip"
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
	parts := strings.Fields(acl)
	if len(parts) == 0 {
		return Matcher{}, fmt.Errorf("Invalid Syntax")
	}

	i := 0
	matcher := Matcher{}
	hasDstMac := false
	switch parts[i] {
	default:
		return Matcher{}, fmt.Errorf("Invalid Action")
	case "permit", "deny":
		matcher.Action = parts[i]
	case "#permit", "#deny":
		matcher.Action = parts[i][1:]
		hasDstMac = true
	}

	i++
	if i >= len(parts) {
		return Matcher{}, fmt.Errorf("Invalid Syntax")
	}

	switch parts[i] {
	default:
		return Matcher{}, fmt.Errorf("Invalid Proto")
	case "tcp", "udp", "icmp":
		matcher.Proto = IpProtocol(parts[i])
	}

	i++
	if i >= len(parts) {
		return Matcher{}, fmt.Errorf("Invalid Syntax")
	}
	if parts[i] != "any" {
		return Matcher{}, fmt.Errorf("Invalid Src Address")
	}

	matcher.SrcNet = AnyPrefix
	i++
	if i >= len(parts) {
		return Matcher{}, fmt.Errorf("Invalid Syntax")
	}

	switch parts[i] {
	default:

		ip, err := netip.ParseAddr(parts[i])
		if err != nil {
			return Matcher{}, fmt.Errorf("Invalid Dst Address: %w", err)
		}

		i++
		if i >= len(parts) {
			return Matcher{}, fmt.Errorf("Invalid Syntax")
		}
		mask, err := netip.ParseAddr(parts[i])
		if err != nil {
			return Matcher{}, fmt.Errorf("Invalid Dst Address: %w", err)
		}

		if !mask.Is4() {
			return Matcher{}, fmt.Errorf("Invalid Dst Wildcard Invalid Syntax")
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
			return Matcher{}, fmt.Errorf("Invalid Syntax")
		}
		if hasDstMac {
			destMac, err := mac.NewFromString(parts[i])
			if err != nil {
				return Matcher{}, fmt.Errorf("Invalid Dst Mac: %w", err)
			}

			matcher.DstNet = AnyPrefix
			matcher.DstMac = destMac
			break
		}

		p, err := netip.ParsePrefix(parts[i] + "/32")
		if err != nil {
			return Matcher{}, fmt.Errorf("Invalid Dst Address: %w", err)
		}

		matcher.DstNet = p
	}

	i++
	if i < len(parts) {
		switch parts[i] {
		default:
			return Matcher{}, fmt.Errorf("Invalid port operation")
		case "eq":
			matcher.Op = parts[i]
			i++
			if i >= len(parts) {
				return Matcher{}, fmt.Errorf("Invalid Syntax")
			}
			port, err := strconv.ParseUint(parts[i], 10, 16)
			if err != nil {
				return Matcher{}, fmt.Errorf("Invalid port:%w", err)
			}
			matcher.Port = int(port)
		}
	}

	return matcher, nil
}

type Matcher struct {
	Action string
	DstMac mac.Mac
	Op     string
	Proto  IpProtocol
	Port   int
	SrcNet netip.Prefix
	DstNet netip.Prefix
}

func (m *Matcher) Matches(ne *NetworkEvent) bool {
	return m.Port == ne.DestPort && m.Proto == ne.IpProtocol && m.SrcNet.Contains(ne.SourceIp) && m.matchDest(ne)
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

func (l PolicyLookup) Lookup(ctx context.Context, db *sql.DB, ne *NetworkEvent) *EnforcementInfo {
	srcMac, srcRole := ne.GetSrcRole(ctx, db)
	dstMac, dstRole := ne.GetDstRole(ctx, db)
	if ei := l.LookupByMac(srcMac, ne); ei != nil {
		return ei
	}

	if ei := l.LookupByMac(dstMac, ne); ei != nil {
		return ei
	}

	if ei := l.LookupByRoles(srcRole, ne); ei != nil {
		return ei
	}

	if ei := l.LookupByRoles(dstRole, ne); ei != nil {
		return ei
	}

	if srcMac != "" {
		return l.LookupImplict(ne)
	}

	return nil
}

func (l *PolicyLookup) LookupByRoles(role string, ne *NetworkEvent) *EnforcementInfo {
	policies, ok := l.ByRoles[role]
	if !ok {
		return nil
	}

	if ei := matchEnforcementInfo(policies, ne); ei != nil {
		return ei
	}

	return nil
}

func (l *PolicyLookup) LookupByMac(mac string, ne *NetworkEvent) *EnforcementInfo {
	policies, ok := l.NodesPolicies[mac]
	if !ok {
		return nil
	}

	if ei := matchEnforcementInfo(policies, ne); ei != nil {
		return ei
	}

	return nil
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

func (l *PolicyLookup) UpdateMatchers() {
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
