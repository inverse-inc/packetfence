package maint

import (
	"testing"
)

func TestSecurityEventMaintenance(t *testing.T) {
	testWindowSqlCleanup(
		t,
        "security_event_maintenance",
        map[string]interface{}{},
        []string{`
        CREATE OR REPLACE TABLE security_event_maintenance_test_mac SELECT '00:11:22:22:33:44' as mac
        `},
        []sqlCountTest{},
        []string{},
    )
}
