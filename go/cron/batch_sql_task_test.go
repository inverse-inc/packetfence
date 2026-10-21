package maint

import (
	"testing"
	"time"
)

func testBatchSqlCleanup(t *testing.T, name string, additional_args map[string]interface{}, setupSql []string, pause time.Duration, tests []sqlCountTest, cleanupSQL []string) {
	config, found := jobsConfig[name]
	if !found {
		t.Fatalf("config for %s not found", name)
	}

	testCronTask(
		t,
		BuildJob(
			name,
			MergeArgs(
				config.(map[string]interface{}),
				additional_args,
			),
		),
		setupSql,
		pause,
		tests,
		cleanupSQL,
	)
}

func TestSwitchObservabilityAclsCleanup(t *testing.T) {

	testBatchSqlCleanup(
		t,
		"switch_observability_acls_cleanup",
		map[string]interface{}{
			"timeout": 10.0,
			"batch":   100.0,
		},
		[]string{
			`DELETE FROM switch_observability_acls WHERE switch_id = 'test-switch-obs'`,
			`DELETE FROM node WHERE mac = '02:00:00:00:00:01'`,
			`INSERT INTO node (mac, status) VALUES ('02:00:00:00:00:01', 'unreg')`,
			// The role scoped row (mac = '') and the row whose node still
			// exists must survive. Both orphans must go, including the one
			// enforced a second ago -- there is no grace window.
			`
     INSERT INTO switch_observability_acls (switch_id, mac, port, role_id, acl_type, acls, enforcement_timestamp) VALUES
        ('test-switch-obs', '02:00:00:00:00:01', NULL, 'default', 'role', 'permit ip any any', DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ('test-switch-obs', '02:00:00:00:00:02', NULL, 'default', 'role', 'permit ip any any', DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ('test-switch-obs', '02:00:00:00:00:03', NULL, 'default', 'asset', 'permit ip any any', NOW() ),
        ('test-switch-obs', '',                  NULL, 'default', 'role', 'permit ip any any', DATE_SUB(NOW(), INTERVAL 1 DAY) )
            `,
		},
		0,
		[]sqlCountTest{
			{
				name:          "orphaned switch_observability_acls entries gone",
				sql:           `SELECT COUNT(*) FROM switch_observability_acls WHERE switch_id = 'test-switch-obs' AND mac IN ('02:00:00:00:00:02', '02:00:00:00:00:03')`,
				expectedCount: 0,
			},
			{
				name:          "switch_observability_acls entry of an existing node kept",
				sql:           `SELECT COUNT(*) FROM switch_observability_acls WHERE switch_id = 'test-switch-obs' AND mac = '02:00:00:00:00:01'`,
				expectedCount: 1,
			},
			{
				name:          "role scoped switch_observability_acls entry kept",
				sql:           `SELECT COUNT(*) FROM switch_observability_acls WHERE switch_id = 'test-switch-obs' AND mac = ''`,
				expectedCount: 1,
			},
			{
				name:          "switch_observability_acls entries left",
				sql:           `SELECT COUNT(*) FROM switch_observability_acls WHERE switch_id = 'test-switch-obs'`,
				expectedCount: 2,
			},
		},
		[]string{
			`DELETE FROM switch_observability_acls WHERE switch_id = 'test-switch-obs'`,
			`DELETE FROM node WHERE mac = '02:00:00:00:00:01'`,
		},
	)
}
