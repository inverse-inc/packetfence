package uiplugins

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"sort"
	"strings"
)

// maximum nesting and size of a Can expression
const (
	maxCanDepth = 3
	maxCanItems = 16
)

// the target of an ACL rule, the admin role without its action, lowercase
// (eg: SYSLOG_READ is "read syslog", CONFIGURATION_MAIN_READ is
// "read configuration_main")
var canTargetRe = regexp.MustCompile(`^[a-z][a-z0-9_]*$`)

// Can is the ACL an admin needs, the JSON form of the acl.$can, acl.$some and
// acl.$every of the core views:
//
//	"read syslog"                                  acl.$can('read', 'syslog')
//	{"some": ["read syslog", "read system"]}       any of them
//	{"every": ["read syslog", "update syslog"]}    all of them
//
// "some" and "every" can be nested.
type Can struct {
	Rule  string
	Some  []Can
	Every []Can
}

func (c *Can) UnmarshalJSON(b []byte) error {
	b = bytes.TrimSpace(b)
	if len(b) > 0 && b[0] == '"' {
		return json.Unmarshal(b, &c.Rule)
	}
	var o struct {
		Some  []Can `json:"some"`
		Every []Can `json:"every"`
	}
	d := json.NewDecoder(bytes.NewReader(b))
	d.DisallowUnknownFields()
	if err := d.Decode(&o); err != nil {
		return fmt.Errorf("a can is \"<verb> <target>\", {\"some\": [...]} or {\"every\": [...]}: %w", err)
	}
	c.Some, c.Every = o.Some, o.Every
	return nil
}

func (c Can) MarshalJSON() ([]byte, error) {
	switch {
	case c.Rule != "":
		return json.Marshal(c.Rule)
	case c.Some != nil:
		return json.Marshal(map[string][]Can{"some": c.Some})
	default:
		return json.Marshal(map[string][]Can{"every": c.Every})
	}
}

func (c *Can) validate(catalog *Catalog, depth int) error {
	set := 0
	for _, b := range []bool{c.Rule != "", c.Some != nil, c.Every != nil} {
		if b {
			set++
		}
	}
	if set != 1 {
		return errors.New("needs exactly one of \"<verb> <target>\", some or every")
	}
	if c.Rule != "" {
		parts := strings.Split(c.Rule, " ")
		if len(parts) != 2 || !canTargetRe.MatchString(parts[1]) {
			return fmt.Errorf("%q must be \"<verb> <target>\"", c.Rule)
		}
		if !contains(catalog.ACL.Verbs, parts[0]) {
			return fmt.Errorf("%q: unknown verb %q, one of %v", c.Rule, parts[0], catalog.ACL.Verbs)
		}
		return nil
	}
	if depth >= maxCanDepth {
		return fmt.Errorf("some/every nested more than %d levels", maxCanDepth)
	}
	list := c.Some
	if c.Every != nil {
		list = c.Every
	}
	if len(list) == 0 || len(list) > maxCanItems {
		return fmt.Errorf("some/every needs 1 to %d items", maxCanItems)
	}
	for i := range list {
		if err := list[i].validate(catalog, depth+1); err != nil {
			return err
		}
	}
	return nil
}

// Validate checks a Can against the ACL verbs of the catalog
func (c *Can) Validate(catalog *Catalog) error {
	return c.validate(catalog, 0)
}

// Role is the admin role of a rule "<verb> <target>", the reverse of the
// setupAcl of the admin UI: "read syslog" is SYSLOG_READ, "create-multiple
// users" is USERS_CREATE_MULTIPLE, "access <target>" is the role <TARGET>
// without an action.
func Role(rule string) string {
	verb, target, _ := strings.Cut(rule, " ")
	if verb == "access" {
		return strings.ToUpper(target)
	}
	return strings.ToUpper(target) + "_" + strings.ToUpper(strings.ReplaceAll(verb, "-", "_"))
}

// Allowed tells if the admin roles (the X-PacketFence-Admin-Roles of api-aaa)
// satisfy the Can, a nil Can allows everything
func (c *Can) Allowed(roles map[string]bool) bool {
	switch {
	case c == nil:
		return true
	case c.Rule != "":
		return roles[Role(c.Rule)]
	case c.Some != nil:
		for i := range c.Some {
			if c.Some[i].Allowed(roles) {
				return true
			}
		}
		return false
	case c.Every != nil:
		for i := range c.Every {
			if !c.Every[i].Allowed(roles) {
				return false
			}
		}
		return len(c.Every) > 0
	}
	return false // an empty Can: deny, like the admin UI
}

// APIMethod is the path of an API method of the manifest, relative to
// /api/v1/plugin/<name>/ (the plugin service), and for the write methods the ACL needed to offer it:
//
//	"config/syslog_forwarder/{id}"
//	{"path": "config/syslog_forwarder/{id}", "can": "delete syslog"}
type APIMethod struct {
	Path string
	Can  *Can
}

func (a *APIMethod) UnmarshalJSON(b []byte) error {
	b = bytes.TrimSpace(b)
	if len(b) > 0 && b[0] == '"' {
		return json.Unmarshal(b, &a.Path)
	}
	var o struct {
		Path string `json:"path"`
		Can  *Can   `json:"can"`
	}
	d := json.NewDecoder(bytes.NewReader(b))
	d.DisallowUnknownFields()
	if err := d.Decode(&o); err != nil {
		return fmt.Errorf("an api method is a path or {\"path\": ..., \"can\": ...}: %w", err)
	}
	a.Path, a.Can = o.Path, o.Can
	return nil
}

func (a APIMethod) MarshalJSON() ([]byte, error) {
	if a.Can == nil {
		return json.Marshal(a.Path)
	}
	return json.Marshal(struct {
		Path string `json:"path"`
		Can  *Can   `json:"can"`
	}{a.Path, a.Can})
}

// targets adds the targets (uppercase, as in the admin roles) of the rules of
// a Can
func (c *Can) targets(into map[string]bool) {
	if c == nil {
		return
	}
	if c.Rule != "" {
		_, target, _ := strings.Cut(c.Rule, " ")
		into[strings.ToUpper(target)] = true
		return
	}
	for i := range c.Some {
		c.Some[i].targets(into)
	}
	for i := range c.Every {
		c.Every[i].targets(into)
	}
}

// Targets are the targets the cans of the manifest name (eg: SYSLOG for
// "read syslog")
func (m *Manifest) Targets() map[string]bool {
	targets := map[string]bool{}
	m.Menu.Can.targets(targets)
	for _, a := range m.API {
		a.Can.targets(targets)
	}
	for _, field := range m.Form.Fields {
		field.Can.targets(targets)
	}
	for _, tab := range m.Form.Tabs {
		tab.Can.targets(targets)
		for _, field := range tab.Fields {
			field.Can.targets(targets)
		}
	}
	return targets
}

// ActionsFor are the actions of the admin on the targets the manifest names:
// <TARGET>_<ACTION>, or <TARGET> for an access role
func (m *Manifest) ActionsFor(actions map[string]bool) []string {
	targets := m.Targets()
	list := []string{}
	for action, ok := range actions {
		if !ok {
			continue
		}
		for target := range targets {
			if action == target || strings.HasPrefix(action, target+"_") {
				list = append(list, action)
				break
			}
		}
	}
	sort.Strings(list)
	return list
}
