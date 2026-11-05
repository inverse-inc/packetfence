// Package uiplugins implements the admin UI plugins: the registration of a
// plugin service (the chi_cache table), the validation of the manifest it
// serves, and the proxy to its API.
//
// See docs/ui-plugins/README.md.
package uiplugins

import (
	_ "embed"
	"encoding/json"
)

// catalog.json is generated from html/pfappserver/root/src/plugins/catalog.json
// by html/pfappserver/root/build/ui-plugins-catalog.js, do not edit it.
//
//go:embed catalog.json
var catalogJSON []byte

type CatalogComponent struct {
	Type string `json:"type"`
}

// CatalogAPI lists the API methods of each template, as in the _api.js of the
// core views: their fixed HTTP verb, and whether their path has an {id}
type CatalogAPI struct {
	Verbs   map[string]string          `json:"verbs"`
	Methods map[string]map[string]bool `json:"methods"`
}

// CatalogACL lists the verbs of the admin roles ACL (src/utils/acl.js
// ADMIN_ROLES_ACTIONS, "_" replaced by "-")
type CatalogACL struct {
	Verbs []string `json:"verbs"`
	// the API methods that can have their own can, menu.can covers the others
	Methods []string `json:"methods"`
}

type CatalogValidator struct {
	Types []string `json:"types"`
	Args  []string `json:"args"`
}

// Catalog lists what a manifest may use: everything else is refused, a
// plugin can only use what core already provides.
type Catalog struct {
	ManifestVersions []int                       `json:"manifestVersions"`
	Templates        []string                    `json:"templates"`
	Areas            []string                    `json:"areas"`
	API              CatalogAPI                  `json:"api"`
	ACL              CatalogACL                  `json:"acl"`
	Components       map[string]CatalogComponent `json:"components"`
	Validators       map[string]CatalogValidator `json:"validators"`
	// the props a manifest field cannot set: set from the field properties,
	// or rendered as HTML by the core components
	ForbiddenProps []string `json:"forbiddenProps"`
}

var DefaultCatalog = mustCatalog(catalogJSON)

func mustCatalog(b []byte) *Catalog {
	c := &Catalog{}
	if err := json.Unmarshal(b, c); err != nil {
		panic("uiplugins: invalid catalog.json: " + err.Error())
	}
	return c
}

func contains[T comparable](list []T, v T) bool {
	for _, i := range list {
		if i == v {
			return true
		}
	}
	return false
}
