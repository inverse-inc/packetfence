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
	"github.com/smallstep/nosql/database"
)

var AnyPrefix = netip.MustParsePrefix("0.0.0.0/0")

func ParseAcl(acl string) (Matcher, error) {
	parts := strings.Fields(acl)
	i := 0
	matcher := Matcher{}
	switch parts[i] {
	default:
		return Matcher{}, fmt.Errorf("Invalid Action")
	case "permit", "deny":
		matcher.Action = parts[i]
	}

	i++
	switch parts[i] {
	default:
		return Matcher{}, fmt.Errorf("Invalid Proto")
	case "tcp", "udp", "icmp":
		matcher.Proto = IpProtocol(parts[i])
	}

	i++
	if parts[i] != "any" {
		return Matcher{}, fmt.Errorf("Invalid Src Address")
	}

	matcher.SrcNet = AnyPrefix
	i++

	switch parts[i] {
	default:
		ip, err := netip.ParseAddr(parts[i])
		if err != nil {
			return Matcher{}, fmt.Errorf("Invalid Dst address: %w", err)
		}

		i++
		ip2, err := netip.ParseAddr(parts[i])
		if err != nil {
			return Matcher{}, fmt.Errorf("Invalid Dst address: %w", err)
		}

		if !ip2.Is4() {
			return Matcher{}, fmt.Errorf("Invalid Dst wildcard invalid syntax")
		}

		a4 := ip2.As4()
		for i, b := range a4 {
			a4[i] = ^b
		}

		one, _ := net.IPv4Mask(a4[0], a4[1], a4[2], a4[3]).Size()
		matcher.DstNet = netip.PrefixFrom(ip, one)
	case "any":
		matcher.DstNet = AnyPrefix
	case "host":
		i++
		p, err := netip.ParsePrefix(parts[i] + "/32")
		if err != nil {
			return Matcher{}, fmt.Errorf("Invalid Dst: %w", err)
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
	Op     string
	Proto  IpProtocol
	Port   int
	SrcNet netip.Prefix
	DstNet netip.Prefix
}

func (m *Matcher) Matches(ne *NetworkEvent) bool {
	return m.Port == ne.DestPort && m.Proto == ne.IpProtocol && m.SrcNet.Contains(ne.SourceIp) && m.DstNet.Contains(ne.DestIp)
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
	mac, role := ne.GetSrcRole(ctx, db)
	if mac == "" || role == "" {
		return nil
	}

	if policies, ok := l.NodesPolicies[mac]; ok {
		ei := matchEnforcementInfo(policies, ne)
		if ei != nil {
			return ei
		}
	}

	if policies, ok := l.ByRoles[role]; ok {
		ei := matchEnforcementInfo(policies, ne)
		if ei != nil {
			return ei
		}
	}

	return l.LookupImplict(ne)
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
