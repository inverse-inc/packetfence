package uiplugins

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// the embedded catalog must be the one generated from the UI catalog
func TestCatalogIsCurrent(t *testing.T) {
	b, err := os.ReadFile(filepath.Join("..", "..", "html", "pfappserver", "root", "src", "plugins", "catalog.json"))
	if err != nil {
		t.Skip("UI catalog not available: ", err)
	}
	ui := map[string]any{}
	if err := json.Unmarshal(b, &ui); err != nil {
		t.Fatal(err)
	}
	delete(ui, "$comment")
	embedded := map[string]any{}
	if err := json.Unmarshal(catalogJSON, &embedded); err != nil {
		t.Fatal(err)
	}
	a, _ := json.Marshal(ui)
	e, _ := json.Marshal(embedded)
	if string(a) != string(e) {
		t.Error("go/uiplugins/catalog.json is not current, run: node html/pfappserver/root/build/ui-plugins-catalog.js")
	}
}

const valid = `{
  "manifestVersion": 1,
  "id": "acme",
  "title": {"en": "Acme"},
  "menu": {"area": "configuration", "section": "/configuration/integration", "can": "read syslog"},
  "template": "collection",
  "api": {"list": "acme/items", "item": "acme/item/{id}", "update": {"path": "acme/item/{id}", "can": "update syslog"}},
  "collection": {"columns": [{"key": "id", "label": {"en": "Id"}}]},
  "form": {"fields": [
    {"namespace": "id", "component": "BaseFormGroupInput", "validators": [{"fn": "required"}]},
    {"namespace": "port", "component": "BaseFormGroupInputNumber", "validators": [{"fn": "isPort"}], "when": {"field": "id", "notEquals": ""}},
    {"namespace": "tags", "component": "BaseFormGroupChosenMultiple", "validators": [{"fn": "unique"}, {"fn": "min", "args": [1]}]}
  ]}
}`

// apply a JSON change to the valid manifest
func manifestWith(t *testing.T, change func(m map[string]any)) []byte {
	m := map[string]any{}
	if err := json.Unmarshal([]byte(valid), &m); err != nil {
		t.Fatal(err)
	}
	change(m)
	b, _ := json.Marshal(m)
	return b
}

func field(m map[string]any, i int) map[string]any {
	return m["form"].(map[string]any)["fields"].([]any)[i].(map[string]any)
}

// the can forms, and the manifest the API sends to the UI keeps them
func TestManifestCan(t *testing.T) {
	b := manifestWith(t, func(m map[string]any) {
		m["menu"].(map[string]any)["can"] = map[string]any{"some": []any{"read syslog", map[string]any{"every": []any{"read system", "create-multiple users"}}}}
		m["api"].(map[string]any)["update"] = map[string]any{"path": "acme/item/{id}", "can": "update syslog"}
		field(m, 1)["can"] = "update syslog"
	})
	m, err := ParseManifest(b)
	if err != nil {
		t.Fatal(err)
	}
	if err := m.Validate(DefaultCatalog, "acme"); err != nil {
		t.Fatalf("refused: %s", err)
	}
	out, err := json.Marshal(m)
	if err != nil {
		t.Fatal(err)
	}
	got := map[string]any{}
	json.Unmarshal(out, &got)
	expected := map[string]any{}
	json.Unmarshal(b, &expected)
	for _, path := range [][]string{{"menu", "can"}, {"api", "update"}, {"api", "list"}} {
		g, e := got[path[0]].(map[string]any)[path[1]], expected[path[0]].(map[string]any)[path[1]]
		gj, _ := json.Marshal(g)
		ej, _ := json.Marshal(e)
		if string(gj) != string(ej) {
			t.Errorf("%v: sent %s, expected %s", path, gj, ej)
		}
	}
	if c := field(got, 1)["can"]; c != "update syslog" {
		t.Errorf("field can sent as %v", c)
	}
}

func TestManifestValidate(t *testing.T) {
	m, err := ParseManifest([]byte(valid))
	if err != nil {
		t.Fatal(err)
	}
	if err := m.Validate(DefaultCatalog, "acme"); err != nil {
		t.Fatalf("valid manifest refused: %s", err)
	}

	tests := []struct {
		name   string
		change func(m map[string]any)
		error  string
	}{
		{"unknown property", func(m map[string]any) { m["script"] = "alert(1)" }, "unknown field"},
		{"manifest version", func(m map[string]any) { m["manifestVersion"] = 2 }, "unsupported manifestVersion"},
		{"other id", func(m map[string]any) { m["id"] = "other" }, "does not match"},
		{"title without en", func(m map[string]any) { m["title"] = map[string]any{"fr": "Acme"} }, "\"en\""},
		{"name without en", func(m map[string]any) { m["name"] = map[string]any{"fr": "Acme"} }, "\"en\""},
		{"invalid icon", func(m map[string]any) { m["icon"] = "Acme Icon" }, "invalid icon"},
		{"icon path with markup", func(m map[string]any) {
			m["icons"] = map[string]any{"bell": map[string]any{"width": 16, "height": 16, "paths": []any{`M0 0"/><script>`}}}
		}, "invalid path data"},
		{"icon size", func(m map[string]any) {
			m["icons"] = map[string]any{"bell": map[string]any{"width": 0, "height": 16, "paths": []any{"M0 0h16v16z"}}}
		}, "width and height"},
		{"icon name", func(m map[string]any) {
			m["icons"] = map[string]any{"Bell": map[string]any{"width": 16, "height": 16, "paths": []any{"M0 0h16v16z"}}}
		}, "invalid name"},
		{"own icon not shipped", func(m map[string]any) { m["icon"] = "acme/bell" }, "has no icons.bell"},
		{"area", func(m map[string]any) { m["menu"].(map[string]any)["area"] = "reports" }, "menu.area"},
		{"section of another area", func(m map[string]any) { m["menu"].(map[string]any)["section"] = "/status/x" }, "must be a path under /configuration/"},
		{"can", func(m map[string]any) { m["menu"].(map[string]any)["can"] = "read" }, "menu.can"},
		{"template", func(m map[string]any) { m["template"] = "wizard" }, "template"},
		{"collection without columns", func(m map[string]any) { delete(m, "collection") }, "collection.columns"},
		{"collection on a resource", func(m map[string]any) {
			m["template"] = "resource"
			m["api"] = map[string]any{"item": "acme/settings"}
		}, "only allowed with the collection template"},
		{"unknown api method", func(m map[string]any) { m["api"].(map[string]any)["purge"] = "acme/items" }, "not a method"},
		{"api path without id", func(m map[string]any) { m["api"].(map[string]any)["item"] = "acme/item" }, "needs the {id}"},
		{"api path with id", func(m map[string]any) { m["api"].(map[string]any)["list"] = "acme/{id}/items" }, "cannot have an {id}"},
		{"absolute api path", func(m map[string]any) { m["api"].(map[string]any)["list"] = "https://evil/items" }, "invalid path"},
		{"api path traversal", func(m map[string]any) { m["api"].(map[string]any)["list"] = "acme/../config/admin_roles" }, "invalid path"},
		{"no item", func(m map[string]any) { delete(m["api"].(map[string]any), "item") }, "api.item is required"},
		{"no list nor search", func(m map[string]any) { delete(m["api"].(map[string]any), "list") }, "api.list or api.search"},
		{"unknown component", func(m map[string]any) { field(m, 0)["component"] = "AcmeWidget" }, "unknown component"},
		{"unknown validator", func(m map[string]any) {
			field(m, 0)["validators"] = []any{map[string]any{"fn": "eval"}}
		}, "unknown validator"},
		{"validator of another type", func(m map[string]any) {
			field(m, 2)["validators"] = []any{map[string]any{"fn": "isPort"}}
		}, "does not apply"},
		{"validator arguments", func(m map[string]any) {
			field(m, 2)["validators"] = []any{map[string]any{"fn": "min", "args": []any{"one"}}}
		}, "must be a integer"},
		{"validator argument count", func(m map[string]any) {
			field(m, 2)["validators"] = []any{map[string]any{"fn": "min"}}
		}, "takes 1 argument"},
		{"invalid regexp", func(m map[string]any) {
			field(m, 0)["validators"] = []any{map[string]any{"fn": "matches", "args": []any{"("}}}
		}, "invalid regular expression"},
		{"when unknown field", func(m map[string]any) { field(m, 1)["when"] = map[string]any{"field": "nope", "equals": 1} }, "another field"},
		{"when two conditions", func(m map[string]any) {
			field(m, 1)["when"] = map[string]any{"field": "id", "equals": 1, "in": []any{1}}
		}, "exactly one"},
		{"duplicate namespace", func(m map[string]any) { field(m, 1)["namespace"] = "id" }, "used twice"},
		{"props override", func(m map[string]any) { field(m, 0)["props"] = map[string]any{"namespace": "x"} }, "not allowed"},
		{"props rendered as HTML", func(m map[string]any) {
			field(m, 0)["props"] = map[string]any{"apiFeedback": "<img src=x onerror=alert(1)>"}
		}, "not allowed"},
		{"can unknown verb", func(m map[string]any) { m["menu"].(map[string]any)["can"] = "read_sponsored users" }, "unknown verb"},
		{"can target", func(m map[string]any) { m["menu"].(map[string]any)["can"] = "read Syslog" }, "must be"},
		{"can empty some", func(m map[string]any) { m["menu"].(map[string]any)["can"] = map[string]any{"some": []any{}} }, "1 to 16"},
		{"can some and every", func(m map[string]any) {
			m["menu"].(map[string]any)["can"] = map[string]any{"some": []any{"read syslog"}, "every": []any{"read syslog"}}
		}, "exactly one"},
		{"can unknown operator", func(m map[string]any) {
			m["menu"].(map[string]any)["can"] = map[string]any{"none": []any{"read syslog"}}
		}, "unknown field"},
		{"can too deep", func(m map[string]any) {
			m["menu"].(map[string]any)["can"] = map[string]any{"some": []any{map[string]any{"every": []any{map[string]any{"some": []any{map[string]any{"every": []any{"read syslog"}}}}}}}}
		}, "nested more than"},
		{"field can", func(m map[string]any) { field(m, 1)["can"] = "read" }, "can:"},
		{"api can on a read method", func(m map[string]any) {
			m["api"].(map[string]any)["list"] = map[string]any{"path": "acme/items", "can": "read syslog"}
		}, "can is only allowed on"},
		{"api object path", func(m map[string]any) {
			m["api"].(map[string]any)["update"] = map[string]any{"path": "acme/item", "can": "update syslog"}
		}, "needs the {id}"},
		{"api object unknown property", func(m map[string]any) {
			m["api"].(map[string]any)["update"] = map[string]any{"path": "acme/item/{id}", "verb": "PUT"}
		}, "unknown field"},
		{"no menu.can", func(m map[string]any) { delete(m["menu"].(map[string]any), "can") }, "menu.can is required"},
		{"write without can", func(m map[string]any) { m["api"].(map[string]any)["update"] = "acme/item/{id}" }, "api.update needs a can"},
		{"create without can", func(m map[string]any) { m["api"].(map[string]any)["create"] = "acme/items" }, "api.create needs a can"},
		{"two ids", func(m map[string]any) { m["api"].(map[string]any)["item"] = "acme/{id}/{id}/{id}/user/admin" }, "one {id} only"},
		{"search is create", func(m map[string]any) {
			m["api"].(map[string]any)["search"] = "acme/items"
			m["api"].(map[string]any)["create"] = map[string]any{"path": "acme/items", "can": "create syslog"}
		}, "same path"},
		{"__proto__ namespace", func(m map[string]any) { field(m, 1)["namespace"] = "__proto__.polluted" }, "invalid namespace"},
		{"constructor namespace", func(m map[string]any) { field(m, 1)["namespace"] = "a.constructor.prototype" }, "invalid namespace"},
		{"__proto__ column", func(m map[string]any) {
			m["collection"].(map[string]any)["columns"] = []any{map[string]any{"key": "__proto__", "label": map[string]any{"en": "x"}}}
		}, "invalid key"},
		{"long regexp", func(m map[string]any) {
			field(m, 0)["validators"] = []any{map[string]any{"fn": "matches", "args": []any{strings.Repeat("a", 300)}}}
		}, "longer than"},
		{"nested quantifiers", func(m map[string]any) {
			field(m, 0)["validators"] = []any{map[string]any{"fn": "matches", "args": []any{"^(a+)+$"}}}
		}, "nested quantifiers"},
		{"when empty in", func(m map[string]any) { field(m, 1)["when"] = map[string]any{"field": "id", "in": []any{}} }, "at least one value"},
		{"when no operator", func(m map[string]any) { field(m, 1)["when"] = map[string]any{"field": "id"} }, "exactly one"},
		{"fields and tabs", func(m map[string]any) {
			m["form"].(map[string]any)["tabs"] = []any{map[string]any{"title": map[string]any{"en": "T"}, "fields": []any{map[string]any{"namespace": "x", "component": "BaseFormGroupInput"}}}}
		}, "either fields or tabs"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			m, err := ParseManifest(manifestWith(t, test.change))
			if err == nil {
				err = m.Validate(DefaultCatalog, "acme")
			}
			if err == nil {
				t.Fatalf("accepted, expected an error with %q", test.error)
			}
			if !strings.Contains(err.Error(), test.error) {
				t.Errorf("error %q, expected %q", err, test.error)
			}
		})
	}
}

func TestValidateRegex(t *testing.T) {
	accepted := []string{
		`^[a-z]+$`,
		`^(a|b)+$`,
		`^\d{1,3}$`,
		`^[A-Za-z0-9_.-]{1,64}$`,
		`^(?:[a-f0-9]{2}:){5}[a-f0-9]{2}$`,
		`^\d+(?:\.\d)?$`,
		`^\x41\.\-\/\s\S\w\W\b\B\n\r\t\f\v$`,
		`^[\]a]$`,
		`^[^\]]+$`,
		`^a?b*c+d{2}$`,
		`^(?:ab){2,}$`,
		`^(?:[a-f0-9]{2}[:-]){5}[a-f0-9]{2}$`,
	}
	for _, re := range accepted {
		if err := validateRegex(re); err != nil {
			t.Errorf("%s refused: %s", re, err)
		}
	}
	refused := map[string]string{
		// catastrophic backtracking in the browser
		`^((a+)b?)*$`:  "nested quantifiers",
		`^(a|aa)+$`:    "nested quantifiers",
		`^(\d+\.?)+$`:  "nested quantifiers",
		`(a+)+`:        "nested quantifiers",
		`^(a*)*$`:      "nested quantifiers",
		`^(ab|cd){2}$`: "nested quantifiers",
		`^(x{2,}){3}$`: "nested quantifiers",
		`^(a?){30}$`:   "nested quantifiers",
		// a variable count inside a count: the isIpv4 validator does this one
		`^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$`: "nested quantifiers",
		// RE2 only
		`^(?P<id>[a-z]+)$`: "only ( and (?:",
		`^(?i)abc$`:        "only ( and (?:",
		`^\pL+$`:           "\\p",
		`^[[:alpha:]]+$`:   "POSIX",
		`^abc\z`:           "\\z",
		`^\Aabc`:           "\\A",
		`^\Qa.b\E$`:        "\\Q",
		`^\x{41}$`:         "two hexadecimal digits",
		`^[]a]$`:           "must be escaped",
		`^[a\b]$`:          "character class",
		// JavaScript only (refused by RE2 anyway)
		`^(?=.*\d).+$`: "only ( and (?:",
		`^(a)\1$`:      "\\1",
		`\`:            "trailing backslash",
		// syntax
		`(`:  "invalid regular expression",
		`a{`: "",
	}
	for re, msg := range refused {
		err := validateRegex(re)
		if msg == "" {
			continue // a{ is a literal for both, only checks it does not panic
		}
		if err == nil {
			t.Errorf("%s accepted, expected %q", re, msg)
			continue
		}
		if !strings.Contains(err.Error(), msg) {
			t.Errorf("%s: error %q, expected %q", re, err, msg)
		}
	}
}

// a plugin ships its icons: the manifest names them as "<id>/<name>"
func TestManifestIcons(t *testing.T) {
	var raw map[string]any
	if err := json.Unmarshal([]byte(valid), &raw); err != nil {
		t.Fatal(err)
	}
	raw["icons"] = map[string]any{"bell": map[string]any{"width": 448, "height": 512, "paths": []any{"M224 512c35.3 0 64-28.7 64-64H160c0 35.3 28.7 64 64 64z", "M0 0h448v400H0z"}}}
	raw["icon"] = "acme/bell"
	raw["menu"].(map[string]any)["icon"] = "acme/bell"
	b, _ := json.Marshal(raw)
	m, err := ParseManifest(b)
	if err != nil {
		t.Fatal(err)
	}
	if err := m.Validate(DefaultCatalog, "acme"); err != nil {
		t.Fatalf("a manifest with its own icon refused: %s", err)
	}
	if got := m.Icons["bell"]; got.Width != 448 || len(got.Paths) != 2 {
		t.Fatalf("icons not parsed: %+v", got)
	}
}
