package uiplugins

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strings"
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
	Can     string `json:"can,omitempty"`
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
	Validators  []Validator    `json:"validators,omitempty"`
}

type Tab struct {
	Title  Text    `json:"title"`
	Fields []Field `json:"fields"`
}

type Form struct {
	Fields []Field `json:"fields,omitempty"`
	Tabs   []Tab   `json:"tabs,omitempty"`
}

// Manifest describes the admin UI page of a plugin, see
// docs/ui-plugins/manifest.schema.json
type Manifest struct {
	ManifestVersion int               `json:"manifestVersion"`
	ID              string            `json:"id"`
	Title           Text              `json:"title"`
	Description     Text              `json:"description,omitempty"`
	Menu            Menu              `json:"menu"`
	Template        string            `json:"template"`
	API             map[string]string `json:"api"`
	Collection      *Collection       `json:"collection,omitempty"`
	Form            Form              `json:"form"`
}

var (
	// a path relative to /api/v1, {id} is the only placeholder
	apiPathRe   = regexp.MustCompile(`^[a-z0-9_.-]+(/([a-z0-9_.-]+|\{id\}))*$`)
	namespaceRe = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$`)
	canRe       = regexp.MustCompile(`^[a-z_]+ [a-z_]+$`)
	langRe      = regexp.MustCompile(`^[a-z]{2}([_-][A-Za-z]{2})?$`)
	iconRe      = regexp.MustCompile(`^[a-z0-9-]+(/[a-z0-9-]+)?$`)
)

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
	if !contains(c.ManifestVersions, m.ManifestVersion) {
		return fmt.Errorf("unsupported manifestVersion %d, supported: %v", m.ManifestVersion, c.ManifestVersions)
	}
	if m.ID != id {
		return fmt.Errorf("manifest id %q does not match the registered id %q", m.ID, id)
	}
	if err := m.Title.validate("title", true); err != nil {
		return err
	}
	if err := m.Description.validate("description", false); err != nil {
		return err
	}
	if !contains(c.Areas, m.Menu.Area) {
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
	if m.Menu.Can != "" && !canRe.MatchString(m.Menu.Can) {
		return fmt.Errorf("menu.can %q must be \"<verb> <target>\"", m.Menu.Can)
	}
	if m.Menu.Icon != "" && !iconRe.MatchString(m.Menu.Icon) {
		return fmt.Errorf("invalid menu.icon %q", m.Menu.Icon)
	}
	if !contains(c.Templates, m.Template) {
		return fmt.Errorf("template %q is not one of %v", m.Template, c.Templates)
	}
	if m.Template == "collection" {
		if m.Collection == nil || len(m.Collection.Columns) == 0 {
			return errors.New("a collection needs collection.columns")
		}
		for i, col := range m.Collection.Columns {
			if !namespaceRe.MatchString(col.Key) {
				return fmt.Errorf("collection.columns[%d]: invalid key %q", i, col.Key)
			}
			if err := col.Label.validate(fmt.Sprintf("collection.columns[%d].label", i), true); err != nil {
				return err
			}
		}
		for i, f := range m.Collection.SearchFields {
			if !namespaceRe.MatchString(f) {
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
	for method, path := range m.API {
		needsID, found := methods[method]
		if !found {
			return fmt.Errorf("api.%s is not a method of the %s template", method, m.Template)
		}
		if !apiPathRe.MatchString(path) || strings.Contains(path, "..") {
			return fmt.Errorf("api.%s: invalid path %q, a path relative to /api/v1", method, path)
		}
		if hasID := strings.Contains(path, "{id}"); hasID != needsID {
			if needsID {
				return fmt.Errorf("api.%s: the path %q needs the {id} of the item", method, path)
			}
			return fmt.Errorf("api.%s: the path %q cannot have an {id}", method, path)
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
	if !namespaceRe.MatchString(f.Namespace) {
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
		switch prop {
		case "namespace", "columnLabel", "text", "placeholder", "textFn":
			return fmt.Errorf("props.%s is not allowed, use the field properties", prop)
		}
	}
	if f.When != nil {
		if !namespaces[f.When.Field] || f.When.Field == f.Namespace {
			return fmt.Errorf("when.field %q must be another field of the form", f.When.Field)
		}
		set := 0
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
		if !contains(validator.Types, component.Type) {
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
			if _, err := regexp.Compile(v.Args[0].(string)); err != nil {
				return fmt.Errorf("validators[%d]: invalid regular expression: %w", i, err)
			}
		}
		if err := v.Message.validate(fmt.Sprintf("validators[%d].message", i), false); err != nil {
			return err
		}
	}
	return nil
}
