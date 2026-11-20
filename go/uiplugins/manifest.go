package uiplugins

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"regexp/syntax"
	"slices"
	"strings"
	"time"
)

// Text is a translatable text: { "en": "...", "fr": "..." }, "en" is required
type Text map[string]string

type Menu struct {
	Area    string `json:"area"`
	Section string `json:"section,omitempty"`
	Group   string `json:"group,omitempty"`
	Before  string `json:"before,omitempty"`
	After   string `json:"after,omitempty"`
	Icon    string `json:"icon,omitempty"`
	Can     *Can   `json:"can,omitempty"`
}

type Column struct {
	Key      string `json:"key"`
	Label    Text   `json:"label"`
	Sortable bool   `json:"sortable,omitempty"`
}

type Collection struct {
	Columns      []Column `json:"columns"`
	SearchFields []string `json:"searchFields,omitempty"`
}

type When struct {
	Field     string `json:"field"`
	Equals    any    `json:"equals,omitempty"`
	NotEquals any    `json:"notEquals,omitempty"`
	In        []any  `json:"in,omitempty"`
}

type Validator struct {
	Fn      string `json:"fn"`
	Args    []any  `json:"args,omitempty"`
	Message Text   `json:"message,omitempty"`
}

type Field struct {
	Namespace   string         `json:"namespace"`
	Component   string         `json:"component"`
	Label       Text           `json:"label,omitempty"`
	Text        Text           `json:"text,omitempty"`
	Placeholder Text           `json:"placeholder,omitempty"`
	Props       map[string]any `json:"props,omitempty"`
	When        *When          `json:"when,omitempty"`
	Can         *Can           `json:"can,omitempty"`
	Validators  []Validator    `json:"validators,omitempty"`
}

type Tab struct {
	Title  Text    `json:"title"`
	Can    *Can    `json:"can,omitempty"`
	Fields []Field `json:"fields"`
}

type Form struct {
	Fields []Field `json:"fields,omitempty"`
	Tabs   []Tab   `json:"tabs,omitempty"`
}

// Manifest describes the admin UI page of a plugin, see
// docs/ui-plugins/manifest.schema.json
type Manifest struct {
	ManifestVersion int                  `json:"manifestVersion"`
	ID              string               `json:"id"`
	Name            Text                 `json:"name,omitempty"`
	Title           Text                 `json:"title"`
	Description     Text                 `json:"description,omitempty"`
	Icon            string               `json:"icon,omitempty"`
	Icons           map[string]IconData  `json:"icons,omitempty"`
	Menu            Menu                 `json:"menu"`
	Template        string               `json:"template"`
	API             map[string]APIMethod `json:"api,omitempty"`
	Collection      *Collection          `json:"collection,omitempty"`
	Form            Form                 `json:"form"`
	Bundle          *Bundle              `json:"bundle,omitempty"`
}

// Bundle is the page of a plugin that ships its own UI code (template
// "bundle"): its API is passed through (Passthrough), any path under
// /api/v1/plugin/<name>/, PLUGIN_READ for GET and OPTIONS, PLUGIN_WRITE for
// POST, PUT, PATCH and DELETE
type Bundle struct {
	// the version of the host API of the admin UI the code is built for
	HostAPI int `json:"hostApi"`
	// where core mounts the code: "page" (a route and its sidebar item, from
	// menu), "navbar-panel" (a navbar button opening a panel)
	Mounts []string `json:"mounts"`
	// the navbar button of the "navbar-panel" mount
	Navbar *BundleNavbar `json:"navbar,omitempty"`
	// seconds a call to the plugin may take, DefaultPassthroughTimeout when 0
	Timeout int `json:"timeout,omitempty"`
	// the code may open WebSockets on /api/v1/plugin/<name>/<path> (a GET,
	// PLUGIN_READ, authenticated by the token cookie of the admin UI): they
	// are passed through, without the timeout, see Fetcher.Proxy
	WebSockets bool `json:"websockets,omitempty"`
}

// IconData is an icon a plugin ships (the format of vue-awesome): the admin UI
// registers it when it loads the plugin, as "<plugin id>/<name>", so a plugin
// never needs an icon added to the admin UI (no rebuild). The paths are SVG
// path data, rendered as the d attribute of a path: no markup.
type IconData struct {
	Width  int      `json:"width"`
	Height int      `json:"height"`
	Paths  []string `json:"paths"`
}

// BundleNavbar is the navbar button of a bundle, shown to the admins who
// satisfy menu.can
type BundleNavbar struct {
	Icon string `json:"icon"`
}

// HasMount tells if core mounts the bundle at mount
func (b *Bundle) HasMount(mount string) bool {
	return b != nil && slices.Contains(b.Mounts, mount)
}

// the time a passed through call to a plugin may take
const (
	DefaultPassthroughTimeout = 60
	MaxPassthroughTimeout     = 300
)

// IsBundle tells if the page of the manifest is the plugin's own code: its
// API is passed through
func (m *Manifest) IsBundle() bool {
	return m.Template == "bundle"
}

// PassthroughTimeout is the time a call to a bundle plugin may take
func (m *Manifest) PassthroughTimeout() time.Duration {
	if m.Bundle == nil || m.Bundle.Timeout == 0 {
		return DefaultPassthroughTimeout * time.Second
	}
	return time.Duration(m.Bundle.Timeout) * time.Second
}

var (
	// a path relative to /api/v1/plugin/<name>/, the plugin service, {id} is the only placeholder
	apiPathRe   = regexp.MustCompile(`^[a-z0-9_.-]+(/([a-z0-9_.-]+|\{id\}))*$`)
	namespaceRe = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$`)
	langRe      = regexp.MustCompile(`^[a-z]{2}([_-][A-Za-z]{2})?$`)
	iconRe      = regexp.MustCompile(`^[a-z0-9-]+(/[a-z0-9-]+)?$`)
	iconNameRe  = regexp.MustCompile(`^[a-z0-9-]{1,40}$`)
	iconPathRe  = regexp.MustCompile(`^[MmZzLlHhVvCcSsQqTtAa0-9eE.,+\- \n]+$`)
)

// the namespace segments that reach the prototype of an object in the UI
var forbiddenSegments = map[string]bool{"__proto__": true, "constructor": true, "prototype": true}

// maximum length of a matches regular expression
const maxRegexLength = 256

// validNamespace checks a dotted property path of an item
func validNamespace(namespace string) bool {
	if !namespaceRe.MatchString(namespace) {
		return false
	}
	for _, segment := range strings.Split(namespace, ".") {
		if forbiddenSegments[segment] {
			return false
		}
	}
	return true
}

// ParseManifest decodes a manifest, unknown properties are refused
func ParseManifest(b []byte) (*Manifest, error) {
	m := &Manifest{}
	d := json.NewDecoder(bytes.NewReader(b))
	d.DisallowUnknownFields()
	if err := d.Decode(m); err != nil {
		return nil, fmt.Errorf("invalid manifest: %w", err)
	}
	if d.More() {
		return nil, errors.New("invalid manifest: trailing data")
	}
	return m, nil
}

func (t Text) validate(name string, required bool) error {
	if len(t) == 0 {
		if required {
			return fmt.Errorf("%s is required", name)
		}
		return nil
	}
	if strings.TrimSpace(t["en"]) == "" {
		return fmt.Errorf("%s needs an \"en\" text", name)
	}
	for lang := range t {
		if !langRe.MatchString(lang) {
			return fmt.Errorf("%s: invalid language %q", name, lang)
		}
	}
	return nil
}

func argMatches(kind string, v any) bool {
	switch kind {
	case "integer":
		f, ok := v.(float64)
		return ok && f == float64(int64(f))
	case "string":
		_, ok := v.(string)
		return ok
	case "array":
		_, ok := v.([]any)
		return ok
	}
	return false
}

// Validate checks a manifest against the catalog, id is the registered plugin id
func (m *Manifest) Validate(c *Catalog, id string) error {
	if !slices.Contains(c.ManifestVersions, m.ManifestVersion) {
		return fmt.Errorf("unsupported manifestVersion %d, supported: %v", m.ManifestVersion, c.ManifestVersions)
	}
	if m.ID != id {
		return fmt.Errorf("manifest id %q does not match the registered id %q", m.ID, id)
	}
	if err := m.Name.validate("name", false); err != nil {
		return err
	}
	if err := m.Title.validate("title", true); err != nil {
		return err
	}
	if err := m.validateIcons(); err != nil {
		return err
	}
	if m.Icon != "" && !iconRe.MatchString(m.Icon) {
		return fmt.Errorf("invalid icon %q", m.Icon)
	}
	if err := m.Description.validate("description", false); err != nil {
		return err
	}
	if !slices.Contains(c.Areas, m.Menu.Area) {
		return fmt.Errorf("menu.area %q is not one of %v", m.Menu.Area, c.Areas)
	}
	for name, path := range map[string]string{"section": m.Menu.Section, "before": m.Menu.Before, "after": m.Menu.After} {
		if path != "" && !strings.HasPrefix(path, "/"+m.Menu.Area+"/") {
			return fmt.Errorf("menu.%s %q must be a path under /%s/", name, path, m.Menu.Area)
		}
	}
	if m.Menu.Group != "" && m.Menu.Section == "" {
		return errors.New("menu.group needs a menu.section")
	}
	// required: the API checks it on every call to the plugin
	if m.Menu.Can == nil {
		return errors.New("menu.can is required: the ACL an admin needs to see the page and call the plugin")
	}
	if err := m.Menu.Can.Validate(c); err != nil {
		return fmt.Errorf("menu.can: %w", err)
	}
	if m.Menu.Icon != "" && !iconRe.MatchString(m.Menu.Icon) {
		return fmt.Errorf("invalid menu.icon %q", m.Menu.Icon)
	}
	if !slices.Contains(c.Templates, m.Template) {
		return fmt.Errorf("template %q is not one of %v", m.Template, c.Templates)
	}
	if m.IsBundle() {
		if m.Bundle == nil {
			return errors.New("a bundle needs bundle")
		}
		if len(m.API) > 0 || m.Collection != nil || len(m.Form.Fields) > 0 || len(m.Form.Tabs) > 0 {
			return errors.New("a bundle has no api, collection or form: its API is passed through, its page is its own")
		}
		if m.Bundle.Timeout < 0 || m.Bundle.Timeout > MaxPassthroughTimeout {
			return fmt.Errorf("bundle.timeout %d is not between 1 and %d seconds (0 or none: %d)", m.Bundle.Timeout, MaxPassthroughTimeout, DefaultPassthroughTimeout)
		}
		if !slices.Contains(c.Bundle.HostAPI, m.Bundle.HostAPI) {
			return fmt.Errorf("unsupported bundle.hostApi %d, supported: %v", m.Bundle.HostAPI, c.Bundle.HostAPI)
		}
		if len(m.Bundle.Mounts) == 0 {
			return errors.New("bundle.mounts is required: where the admin UI mounts the bundle")
		}
		seen := map[string]bool{}
		for _, mount := range m.Bundle.Mounts {
			if !slices.Contains(c.Bundle.Mounts, mount) {
				return fmt.Errorf("bundle.mounts: %q is not one of %v", mount, c.Bundle.Mounts)
			}
			if seen[mount] {
				return fmt.Errorf("bundle.mounts: %q twice", mount)
			}
			seen[mount] = true
		}
		if m.Bundle.HasMount("navbar-panel") {
			if m.Bundle.Navbar == nil || !iconRe.MatchString(m.Bundle.Navbar.Icon) {
				return errors.New("the navbar-panel mount needs bundle.navbar.icon")
			}
		} else if m.Bundle.Navbar != nil {
			return errors.New("bundle.navbar is only allowed with the navbar-panel mount")
		}
		return nil
	}
	if m.Bundle != nil {
		return fmt.Errorf("bundle is only allowed with the bundle template")
	}
	if m.Template == "collection" {
		if m.Collection == nil || len(m.Collection.Columns) == 0 {
			return errors.New("a collection needs collection.columns")
		}
		for i, col := range m.Collection.Columns {
			if !validNamespace(col.Key) {
				return fmt.Errorf("collection.columns[%d]: invalid key %q", i, col.Key)
			}
			if err := col.Label.validate(fmt.Sprintf("collection.columns[%d].label", i), true); err != nil {
				return err
			}
		}
		for i, f := range m.Collection.SearchFields {
			if !validNamespace(f) {
				return fmt.Errorf("collection.searchFields[%d]: invalid field %q", i, f)
			}
		}
	} else if m.Collection != nil {
		return fmt.Errorf("collection is only allowed with the collection template")
	}
	if err := m.validateAPI(c); err != nil {
		return err
	}
	return m.Form.validate(c)
}

func (m *Manifest) validateAPI(c *Catalog) error {
	methods := c.API.Methods[m.Template]
	for method, a := range m.API {
		path := a.Path
		needsID, found := methods[method]
		if !found {
			return fmt.Errorf("api.%s is not a method of the %s template", method, m.Template)
		}
		if a.Can == nil && slices.Contains(c.ACL.Methods, method) {
			return fmt.Errorf("api.%s needs a can: {\"path\": ..., \"can\": ...}, the API checks it on every %s", method, method)
		}
		if a.Can != nil {
			if !slices.Contains(c.ACL.Methods, method) {
				return fmt.Errorf("api.%s: can is only allowed on %v, menu.can covers the others", method, c.ACL.Methods)
			}
			if err := a.Can.Validate(c); err != nil {
				return fmt.Errorf("api.%s.can: %w", method, err)
			}
		}
		if !apiPathRe.MatchString(path) || strings.Contains(path, "..") {
			return fmt.Errorf("api.%s: invalid path %q, a path relative to /api/v1/plugin/<name>/", method, path)
		}
		if strings.Count(path, "{id}") > 1 {
			return fmt.Errorf("api.%s: the path %q can have one {id} only", method, path)
		}
		if hasID := strings.Contains(path, "{id}"); hasID != needsID {
			if needsID {
				return fmt.Errorf("api.%s: the path %q needs the {id} of the item", method, path)
			}
			return fmt.Errorf("api.%s: the path %q cannot have an {id}", method, path)
		}
	}
	if search, found := m.API["search"]; found {
		if create, found := m.API["create"]; found && search.Path == create.Path {
			return fmt.Errorf("api.search and api.create cannot have the same path %q", search.Path)
		}
	}
	if _, found := m.API["item"]; !found {
		return errors.New("api.item is required")
	}
	if m.Template == "collection" {
		_, list := m.API["list"]
		_, search := m.API["search"]
		if !list && !search {
			return errors.New("a collection needs api.list or api.search")
		}
	}
	return nil
}

func (f *Form) validate(c *Catalog) error {
	if len(f.Fields) > 0 && len(f.Tabs) > 0 {
		return errors.New("form has either fields or tabs, not both")
	}
	fields := f.Fields
	for i, tab := range f.Tabs {
		if err := tab.Title.validate(fmt.Sprintf("form.tabs[%d].title", i), true); err != nil {
			return err
		}
		if tab.Can != nil {
			if err := tab.Can.Validate(c); err != nil {
				return fmt.Errorf("form.tabs[%d].can: %w", i, err)
			}
		}
		if len(tab.Fields) == 0 {
			return fmt.Errorf("form.tabs[%d] has no fields", i)
		}
		fields = append(fields, tab.Fields...)
	}
	if len(fields) == 0 {
		return errors.New("form has no fields")
	}
	namespaces := map[string]bool{}
	for _, field := range fields {
		if namespaces[field.Namespace] {
			return fmt.Errorf("form: namespace %q is used twice", field.Namespace)
		}
		namespaces[field.Namespace] = true
	}
	for _, field := range fields {
		if err := field.validate(c, namespaces); err != nil {
			return fmt.Errorf("form field %q: %w", field.Namespace, err)
		}
	}
	return nil
}

func (f *Field) validate(c *Catalog, namespaces map[string]bool) error {
	if !validNamespace(f.Namespace) {
		return errors.New("invalid namespace")
	}
	component, found := c.Components[f.Component]
	if !found {
		return fmt.Errorf("unknown component %q, a plugin can only use the core components", f.Component)
	}
	for name, text := range map[string]Text{"label": f.Label, "text": f.Text, "placeholder": f.Placeholder} {
		if err := text.validate(name, false); err != nil {
			return err
		}
	}
	for prop := range f.Props {
		if slices.Contains(c.ForbiddenProps, prop) {
			return fmt.Errorf("props.%s is not allowed (set by the field properties, or rendered as HTML)", prop)
		}
	}
	if f.Can != nil {
		if err := f.Can.Validate(c); err != nil {
			return fmt.Errorf("can: %w", err)
		}
	}
	if f.When != nil {
		if !namespaces[f.When.Field] || f.When.Field == f.Namespace {
			return fmt.Errorf("when.field %q must be another field of the form", f.When.Field)
		}
		set := 0
		if f.When.In != nil && len(f.When.In) == 0 {
			return errors.New("when.in needs at least one value")
		}
		for _, b := range []bool{f.When.Equals != nil, f.When.NotEquals != nil, f.When.In != nil} {
			if b {
				set++
			}
		}
		if set != 1 {
			return errors.New("when needs exactly one of equals, notEquals or in")
		}
	}
	for i, v := range f.Validators {
		validator, found := c.Validators[v.Fn]
		if !found {
			return fmt.Errorf("validators[%d]: unknown validator %q, a plugin can only use the core validators", i, v.Fn)
		}
		if !slices.Contains(validator.Types, component.Type) {
			return fmt.Errorf("validators[%d]: %q does not apply to %s (a %s)", i, v.Fn, f.Component, component.Type)
		}
		if len(v.Args) != len(validator.Args) {
			return fmt.Errorf("validators[%d]: %q takes %d argument(s)", i, v.Fn, len(validator.Args))
		}
		for j, kind := range validator.Args {
			if !argMatches(kind, v.Args[j]) {
				return fmt.Errorf("validators[%d]: argument %d of %q must be a %s", i, j, v.Fn, kind)
			}
		}
		if v.Fn == "matches" {
			if err := validateRegex(v.Args[0].(string)); err != nil {
				return fmt.Errorf("validators[%d]: %w", i, err)
			}
		}
		if err := v.Message.validate(fmt.Sprintf("validators[%d].message", i), false); err != nil {
			return err
		}
	}
	return nil
}

// the escaped letters and digits that mean the same in RE2 and in the
// JavaScript RegExp of the browser (without flags), \x is followed by two
// hexadecimal digits
var portableEscapes = map[byte]bool{
	'd': true, 'D': true, 'w': true, 'W': true, 's': true, 'S': true,
	'b': true, 'B': true, 'n': true, 'r': true, 't': true, 'f': true, 'v': true,
	'x': true,
}

func isHex(c byte) bool {
	return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

func isAlphaNumeric(c byte) bool {
	return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

// portableRegex checks that a regular expression only uses the syntax RE2 (the
// API) and the browser RegExp (the admin UI, where the validator runs) read
// the same way:
//   - escapes: \d \D \w \W \s \S \b \B \n \r \t \f \v, \xHH and an escaped
//     character that is not a letter or a digit (\. \- \/ ...)
//   - groups: ( and (?: only, no flags, named groups or lookarounds
//   - no POSIX classes ([[:alpha:]])
//
// That leaves out, among others, (?P<name>, (?i), \pL, \z, \A, \Q...\E,
// \x{...} and backreferences (\1).
func portableRegex(re string) error {
	inClass := false
	for i := 0; i < len(re); i++ {
		c := re[i]
		switch {
		case c == '\\':
			if i+1 >= len(re) {
				return errors.New("trailing backslash")
			}
			e := re[i+1]
			if isAlphaNumeric(e) && !portableEscapes[e] {
				return fmt.Errorf("the escape \\%c is not supported by both the API and the browser", e)
			}
			if inClass && (e == 'b' || e == 'B') {
				// a backspace in JavaScript, refused by RE2
				return fmt.Errorf("the escape \\%c is not supported in a character class", e)
			}
			if e == 'x' {
				if i+3 >= len(re) || !isHex(re[i+2]) || !isHex(re[i+3]) {
					return errors.New("\\x must be followed by two hexadecimal digits")
				}
				i += 2
			}
			i++
		case inClass:
			if c == '[' && i+1 < len(re) && re[i+1] == ':' {
				return errors.New("POSIX character classes ([[:alpha:]]) are not supported, use a range ([a-zA-Z])")
			}
			if c == ']' {
				inClass = false
			}
		case c == '[':
			inClass = true
			// a ] first in the class is a literal for RE2, an empty class for
			// JavaScript
			if i+1 < len(re) && re[i+1] == '^' {
				i++
			}
			if i+1 < len(re) && re[i+1] == ']' {
				return errors.New("a ] first in a character class must be escaped (\\])")
			}
		case c == '(':
			if i+1 < len(re) && re[i+1] == '?' {
				if i+2 >= len(re) || re[i+2] != ':' {
					return errors.New("only ( and (?: groups are supported: no flags, named groups or lookarounds")
				}
			}
		}
	}
	return nil
}

// repeats tells if a node of the syntax tree can match its sub-expression
// more than once
func repeats(n *syntax.Regexp) bool {
	switch n.Op {
	case syntax.OpStar, syntax.OpPlus:
		return true
	case syntax.OpRepeat:
		return n.Max == -1 || n.Max > 1
	}
	return false
}

// ambiguous tells if a sub-tree holds a quantifier or an alternation: inside a
// repetition the browser engine can then match the same text in exponentially
// many ways. A fixed count ({2}) is not a choice, its sub-tree is checked.
func ambiguous(n *syntax.Regexp) bool {
	switch n.Op {
	case syntax.OpStar, syntax.OpPlus, syntax.OpQuest, syntax.OpAlternate:
		return true
	case syntax.OpRepeat:
		if n.Min != n.Max {
			return true
		}
	}
	for _, sub := range n.Sub {
		if ambiguous(sub) {
			return true
		}
	}
	return false
}

// nestedRepetition finds a repetition of a sub-expression that holds a
// quantifier or an alternation: (a+)+, ((a+)b?)*, (a|aa)+, (\d+\.?)+
func nestedRepetition(n *syntax.Regexp) bool {
	if repeats(n) {
		for _, sub := range n.Sub {
			if ambiguous(sub) {
				return true
			}
		}
	}
	for _, sub := range n.Sub {
		if nestedRepetition(sub) {
			return true
		}
	}
	return false
}

// validateRegex checks the regular expression of a matches validator: it runs
// in the browser on every keystroke, with a backtracking engine
func validateRegex(re string) error {
	if len(re) > maxRegexLength {
		return fmt.Errorf("regular expression longer than %d characters", maxRegexLength)
	}
	if err := portableRegex(re); err != nil {
		return fmt.Errorf("invalid regular expression: %w", err)
	}
	if _, err := regexp.Compile(re); err != nil {
		return fmt.Errorf("invalid regular expression: %w", err)
	}
	tree, err := syntax.Parse(re, syntax.Perl)
	if err != nil {
		return fmt.Errorf("invalid regular expression: %w", err)
	}
	if nestedRepetition(tree) {
		return errors.New("nested quantifiers are not allowed in a regular expression: a repeated group cannot hold a quantifier or an alternation")
	}
	return nil
}

// the limits of the icons a manifest ships
const (
	maxIcons         = 32
	maxIconSize      = 4096
	maxIconPaths     = 32
	maxIconPathBytes = 20000
)

// validateIcons checks the icons the manifest ships, and that an icon of the
// plugin it names ("<id>/<name>": icon, menu.icon, bundle.navbar.icon) is one
// of them
func (m *Manifest) validateIcons() error {
	if len(m.Icons) > maxIcons {
		return fmt.Errorf("icons: %d icons, %d at most", len(m.Icons), maxIcons)
	}
	for name, icon := range m.Icons {
		if !iconNameRe.MatchString(name) {
			return fmt.Errorf("icons: invalid name %q", name)
		}
		if icon.Width < 1 || icon.Width > maxIconSize || icon.Height < 1 || icon.Height > maxIconSize {
			return fmt.Errorf("icons.%s: width and height from 1 to %d", name, maxIconSize)
		}
		if len(icon.Paths) < 1 || len(icon.Paths) > maxIconPaths {
			return fmt.Errorf("icons.%s: from 1 to %d paths", name, maxIconPaths)
		}
		for _, path := range icon.Paths {
			if len(path) > maxIconPathBytes || !iconPathRe.MatchString(path) {
				return fmt.Errorf("icons.%s: invalid path data (SVG path commands and numbers, %d bytes at most)", name, maxIconPathBytes)
			}
		}
	}
	names := map[string]string{"icon": m.Icon, "menu.icon": m.Menu.Icon}
	if m.Bundle != nil && m.Bundle.Navbar != nil {
		names["bundle.navbar.icon"] = m.Bundle.Navbar.Icon
	}
	for field, name := range names {
		if own, found := strings.CutPrefix(name, m.ID+"/"); found {
			if _, shipped := m.Icons[own]; !shipped {
				return fmt.Errorf("%s %q: the manifest has no icons.%s", field, name, own)
			}
		}
	}
	return nil
}
