package maint

import (
	"context"
	"database/sql"
	"fmt"
	"strings"

	"github.com/inverse-inc/go-utils/log"
)

// aclEntry is one line of an ACL pushed to a switch. An entry that cannot be
// parsed is kept as unknown: the switch evaluates the lines in order, so
// nothing can be said about the traffic it might have matched first.
type aclEntry struct {
	matcher Matcher
	// anyProto is set for an "ip" line, which matches every protocol.
	anyProto bool
	unknown  bool
	// line is the position of the entry among the lines of its direction,
	// starting at 1, as the switch numbers them (ip:inacl#101 is line 1).
	line int
}

// pushedAcl is the ACL PacketFence pushed for a node on the switch it is
// connected to (switch_observability_acls), split by direction: in applies to
// the traffic coming from the node, out to the traffic going to it.
type pushedAcl struct {
	switchID string
	role     string
	in, out  []aclEntry
}

// parsePushedAcl parses the ACL text stored in switch_observability_acls, one
// line per entry with an optional in| or out| direction prefix.
func parsePushedAcl(switchID, role, text string) *pushedAcl {
	acl := &pushedAcl{switchID: switchID, role: role}
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "!") || strings.HasPrefix(strings.ToLower(line), "remark") {
			continue
		}

		entries := &acl.in
		if rest, ok := strings.CutPrefix(line, "out|"); ok {
			entries, line = &acl.out, rest
		} else {
			line = strings.TrimPrefix(line, "in|")
		}

		entry, err := parseAclLine(line)
		if err != nil {
			entry = aclEntry{unknown: true}
		}

		entry.line = len(*entries) + 1
		*entries = append(*entries, entry)
	}

	return acl
}

// parseAclLine parses one ACL line as the switch applies it. Unlike the policy
// ACLs it accepts the "ip" protocol, and rejects the #-prefixed MAC lines,
// which PacketFence rewrites or skips when pushing them.
func parseAclLine(line string) (aclEntry, error) {
	if strings.HasPrefix(line, "#") {
		return aclEntry{}, fmt.Errorf("MAC based line: '%s'", line)
	}

	parts := strings.Fields(line)
	if len(parts) < 2 || parts[1] != "ip" {
		matcher, err := ParseAcl(line)
		return aclEntry{matcher: matcher}, err
	}

	parts[1] = "tcp"
	matcher, err := ParseAcl(strings.Join(parts, " "))
	if err != nil {
		return aclEntry{}, err
	}

	if matcher.Op != "" {
		return aclEntry{}, fmt.Errorf("Port on an ip line: '%s'", line)
	}

	return aclEntry{matcher: matcher, anyProto: true}, nil
}

// matches reports whether the event is the traffic of the entry.
func (e *aclEntry) matches(ne *NetworkEvent) bool {
	m := e.matcher
	if e.anyProto {
		m.Proto = ne.IpProtocol
	}

	return m.matchesTraffic(ne)
}

// firstMatch returns the first entry matching the event, or nil when none
// does or an unparsed entry comes first.
func firstMatch(entries []aclEntry, ne *NetworkEvent) *aclEntry {
	for i := range entries {
		e := &entries[i]
		if e.unknown {
			return nil
		}

		if e.matches(ne) {
			return e
		}
	}

	return nil
}

// denyingEntry returns the ACL entry that denies the event on the switch: the
// first matching in line of the source node, else the first matching out line
// of the destination node. The implicit deny at the end of an ACL is not
// reported, the lines stored may not be all the switch applies.
func denyingEntry(acls map[string]*pushedAcl, ne *NetworkEvent) (*pushedAcl, string, *aclEntry) {
	if acl := acls[roleKey(inventoryMac(ne.SourceInventoryItem))]; acl != nil {
		if e := firstMatch(acl.in, ne); e != nil && e.matcher.Action == "deny" {
			return acl, "in", e
		}
	}

	if acl := acls[roleKey(inventoryMac(ne.DestInventoryitem))]; acl != nil {
		if e := firstMatch(acl.out, ne); e != nil && e.matcher.Action == "deny" {
			return acl, "out", e
		}
	}

	return nil, "", nil
}

// applyAclVerdicts reports the events that an ACL pushed by PacketFence
// denies: verdict block and event type failed. When the flows show that the
// connection was established anyway the switch is not enforcing the ACL, and
// the verdict is alert instead. Events that already carry the enforcement info
// of a policy are left alone.
func applyAclVerdicts(ctx context.Context, events []*NetworkEvent, acls map[string]*pushedAcl) {
	if len(acls) == 0 {
		return
	}

	for _, ne := range events {
		if ne.EnforcementInfo != nil {
			continue
		}

		acl, direction, entry := denyingEntry(acls, ne)
		if entry == nil {
			continue
		}

		ei := &EnforcementInfo{
			RuleID:  fmt.Sprintf("packetfence-acl:%s:%s:%s:%d", acl.switchID, acl.role, direction, entry.line),
			Verdict: EnforcementVerdictBlock,
		}

		if ne.answeredTCP() {
			ei.Verdict = EnforcementVerdictAlert
			log.LogWarnf(ctx, "pfflow: %s -> %s:%d was established although the ACL of role %s on switch %s denies it (%s line %d)", ne.SourceIp, ne.DestIp, ne.DestPort, acl.role, acl.switchID, direction, entry.line)
		} else {
			ne.EventType = NetworkEventTypeFailed
		}

		ne.EnforcementInfo = ei
	}
}

const pushedAclsLookupChunk = 1000

// pushedAclsSql selects the ACL pushed for each node on the switch and with
// the role of its open locationlog entry, so that the ACL of a previous role
// or switch is never used.
const pushedAclsSql = `SELECT LOWER(a.mac), a.switch_id, a.role_id, a.acls FROM switch_observability_acls a ` +
	`JOIN locationlog l ON l.mac = a.mac AND l.end_time = '0000-00-00 00:00:00' AND l.role = a.role_id AND a.switch_id IN (l.switch, l.switch_id) ` +
	`WHERE a.mac IN (`

// pushedAcls returns the parsed ACL pushed for each of the macs (roleKey
// normalized) that has one. A failed lookup only leaves macs out.
func pushedAcls(ctx context.Context, db *sql.DB, macs []string) map[string]*pushedAcl {
	acls := map[string]*pushedAcl{}
	if db == nil || len(macs) == 0 {
		return acls
	}

	queryChunks(ctx, db, "pushedAcls", pushedAclsSql, macs, pushedAclsLookupChunk, func(rows *sql.Rows) error {
		var mac, switchID, role, text string
		if err := rows.Scan(&mac, &switchID, &role, &text); err != nil {
			return err
		}

		acls[mac] = parsePushedAcl(switchID, role, text)
		return nil
	})

	return acls
}
