package uiplugins

import (
	"reflect"
	"testing"
)

// the plugin only gets the actions of the targets its manifest names, matched
// exactly: users is not users_sources
func TestActionsForExact(t *testing.T) {
	m := &Manifest{Menu: Menu{Can: &Can{Some: []Can{{Rule: "read users"}, {Rule: "access syslog"}}}}}
	actions := map[string]bool{
		"USERS_READ":              true,
		"USERS_CREATE_MULTIPLE":   true,
		"USERS_SOURCES_READ":      true,
		"USERS_ROLES_READ":        true,
		"USERSX_READ":             true,
		"USERS":                   true,
		"SYSLOG":                  true,
		"SYSLOG_READ":             true,
		"USERS_SET_ACCESS_LEVEL":  true,
		"CONFIGURATION_MAIN_READ": true,
		"USERS_DELETE":            false,
	}
	got := m.ActionsFor(DefaultCatalog, actions)
	want := []string{"SYSLOG", "SYSLOG_READ", "USERS", "USERS_CREATE_MULTIPLE", "USERS_READ", "USERS_SET_ACCESS_LEVEL"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("ActionsFor: got %v, want %v", got, want)
	}
}

// the actions follow the catalog the manifest was validated with: a verb only
// a custom catalog has is passed when that catalog is used
func TestActionsForCatalog(t *testing.T) {
	custom := *DefaultCatalog
	custom.ACL.Verbs = append(append([]string{}, DefaultCatalog.ACL.Verbs...), "approve")
	m := &Manifest{Menu: Menu{Can: &Can{Rule: "approve widgets"}}}
	actions := map[string]bool{"WIDGETS_APPROVE": true}
	if got := m.ActionsFor(DefaultCatalog, actions); len(got) != 0 {
		t.Errorf("ActionsFor(DefaultCatalog): got %v, want none", got)
	}
	if got, want := m.ActionsFor(&custom, actions), []string{"WIDGETS_APPROVE"}; !reflect.DeepEqual(got, want) {
		t.Errorf("ActionsFor(custom): got %v, want %v", got, want)
	}
}
