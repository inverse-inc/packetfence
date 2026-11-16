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
	got := m.ActionsFor(actions)
	want := []string{"SYSLOG", "SYSLOG_READ", "USERS", "USERS_CREATE_MULTIPLE", "USERS_READ", "USERS_SET_ACCESS_LEVEL"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("ActionsFor: got %v, want %v", got, want)
	}
}
