package uiplugins

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// the examples of docs/ui-plugins must be valid
func TestExamples(t *testing.T) {
	for _, id := range []string{"syslog-forwarders", "alerting"} {
		b, err := os.ReadFile(filepath.Join("..", "..", "docs", "ui-plugins", "examples", id, "manifest.json"))
		if err != nil {
			t.Fatal(err)
		}
		m, err := ParseManifest(b)
		if err != nil {
			t.Fatalf("%s: %s", id, err)
		}
		if err := m.Validate(DefaultCatalog, id); err != nil {
			t.Errorf("%s: %s", id, err)
		}
	}
}

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
  "menu": {"area": "configuration", "section": "/configuration/integration"},
  "template": "collection",
  "api": {"list": "acme/items", "item": "acme/item/{id}", "update": "acme/item/{id}"},
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
