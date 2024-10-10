package maint

import (
	"context"
	"testing"
	"time"
)

var jobsConfig = GetMaintenanceConfig(context.Background())

func testWindowSqlCleanup(t *testing.T, name string, additional_args map[string]interface{}, setupSql []string, pause time.Duration, tests []sqlCountTest, cleanupSQL []string) {
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

func TestAdminApiAuditLogCleanup(t *testing.T) {

	testWindowSqlCleanup(
		t,
		"admin_api_audit_log_cleanup",
		map[string]interface{}{
			"timeout": 10.0,
			"batch":   100.0,
			"window":  float64(24 * 60 * 60),
		},
		[]string{
			"DELETE FROM admin_api_audit_log",
			`
     INSERT INTO admin_api_audit_log (created_at) VALUES
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() )
            `,
		},
		0,
		[]sqlCountTest{
			{
				name:          "admin_api_audit_log entries left",
				sql:           ` SELECT COUNT(*) FROM admin_api_audit_log `,
				expectedCount: 8,
			},
		},
		[]string{"DELETE FROM admin_api_audit_log"},
	)
}

func TestAuthLogCleanup(t *testing.T) {

	testWindowSqlCleanup(
		t,
		"auth_log_cleanup",
		map[string]interface{}{
			"timeout": 10.0,
			"batch":   100.0,
			"window":  float64(12 * 60 * 60),
		},
		[]string{
			"DELETE FROM auth_log",
			`
     INSERT INTO auth_log (attempted_at) VALUES
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() )
            `,
		},
		0,
		[]sqlCountTest{
			{
				name:          "auth_log entries left",
				sql:           ` SELECT COUNT(*) FROM auth_log `,
				expectedCount: 8,
			},
		},
		[]string{"DELETE FROM auth_log"},
	)
}

func TestDnsAuditLogCleanup(t *testing.T) {

	testWindowSqlCleanup(
		t,
		"dns_audit_log_cleanup",
		map[string]interface{}{
			"timeout": 10.0,
			"batch":   100.0,
			"window":  float64(12 * 60 * 60),
		},
		[]string{
			"DELETE FROM dns_audit_log",
			`
     INSERT INTO dns_audit_log (created_at) VALUES
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() )
            `,
		},
		0,
		[]sqlCountTest{
			{
				name:          "dns_audit_log entries left",
				sql:           ` SELECT COUNT(*) FROM dns_audit_log `,
				expectedCount: 8,
			},
		},
		[]string{"DELETE FROM dns_audit_log"},
	)
}

func TestRadiusAuditLogCleanup(t *testing.T) {

	testWindowSqlCleanup(
		t,
		"radius_audit_log_cleanup",
		map[string]interface{}{
			"timeout": 10.0,
			"batch":   100.0,
			"window":  float64(12 * 60 * 60),
		},
		[]string{
			"DELETE FROM radius_audit_log",
			`
     INSERT INTO radius_audit_log (created_at) VALUES
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() )
            `,
		},
		0,
		[]sqlCountTest{
			{
				name:          "radius_audit_log entries left",
				sql:           ` SELECT COUNT(*) FROM radius_audit_log `,
				expectedCount: 8,
			},
		},
		[]string{"DELETE FROM radius_audit_log"},
	)
}

func TestLocationlogCleanup(t *testing.T) {

	testWindowSqlCleanup(
		t,
		"locationlog_cleanup",
		map[string]interface{}{
			"timeout": 10.0,
			"batch":   100.0,
			"window":  float64(12 * 60 * 60),
		},
		[]string{
			"DELETE FROM locationlog",
			"DELETE FROM locationlog_history",
			`
     INSERT INTO locationlog (mac, end_time) VALUES
        ("00:00:00:00:00:01", DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ("00:00:00:00:00:02", DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ("00:00:00:00:00:03", DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ("00:00:00:00:00:04", DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ("00:00:00:00:00:05", DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ("00:00:00:00:00:06", DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ("00:00:00:00:00:07", NOW() ),
        ("00:00:00:00:00:08", NOW() ),
        ("00:00:00:00:00:09", NOW() ),
        ("00:00:00:00:00:0a", NOW() ),
        ("00:00:00:00:00:0b", NOW() ),
        ("00:00:00:00:00:0c", NOW() ),
        ("00:00:00:00:00:0d", NOW() ),
        ("00:00:00:00:00:0e", "0000-00-00 00:00:00" )
            `,
			`
     INSERT INTO locationlog_history (mac, end_time) VALUES
        ("00:00:00:00:00:01", DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ("00:00:00:00:00:02", DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ("00:00:00:00:00:03", DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ("00:00:00:00:00:04", DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ("00:00:00:00:00:05", DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ("00:00:00:00:00:06", DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ("00:00:00:00:00:07", NOW() ),
        ("00:00:00:00:00:08", NOW() ),
        ("00:00:00:00:00:09", NOW() ),
        ("00:00:00:00:00:0a", NOW() ),
        ("00:00:00:00:00:0b", NOW() ),
        ("00:00:00:00:00:0c", NOW() ),
        ("00:00:00:00:00:0d", NOW() ),
        ("00:00:00:00:00:0e", "0000-00-00 00:00:00" )
            `,
		},
		0,
		[]sqlCountTest{
			{
				name:          "locationlog entries left",
				sql:           ` SELECT COUNT(*) FROM locationlog `,
				expectedCount: 8,
			},
			{
				name:          "locationlog_history entries left",
				sql:           ` SELECT COUNT(*) FROM locationlog_history `,
				expectedCount: 8,
			},
		},
		[]string{
			"DELETE FROM locationlog",
			"DELETE FROM locationlog_history",
		},
	)
}

func TestAcctCleanup(t *testing.T) {
	testWindowSqlCleanup(
		t,
		"acct_cleanup",
		map[string]interface{}{
			"timeout": 10.0,
			"batch":   100.0,
			"window":  float64(12 * 60 * 60),
		},
		[]string{
			"DELETE FROM radacct",
			"DELETE FROM radacct_log",
			`
     INSERT INTO radacct (acctstarttime) VALUES
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() )
            `,
			`
     INSERT INTO radacct_log (timestamp) VALUES
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( DATE_SUB(NOW(), INTERVAL 1 DAY) ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() ),
        ( NOW() )
            `,
		},
		0,
		[]sqlCountTest{
			{
				name:          "radacct entries left",
				sql:           ` SELECT COUNT(*) FROM radacct `,
				expectedCount: 8,
			},
			{
				name:          "radacct entries left",
				sql:           ` SELECT COUNT(*) FROM radacct_log `,
				expectedCount: 8,
			},
		},
		[]string{
			"DELETE FROM radacct",
			"DELETE FROM radacct_log",
		},
	)
}

func TestNodeCurrentSessionCleanup(t *testing.T) {
	testWindowSqlCleanup(
		t,
		"node_current_session_cleanup",
		map[string]interface{}{
			"timeout": 10.0,
			"batch":   100.0,
			"window":  float64(12 * 60 * 60),
		},
		[]string{
			"DELETE FROM node_current_session",
			`INSERT INTO node_current_session (mac, updated, last_session_id, is_online) VALUES
				( "00:11:22:33:44:55", DATE_SUB(NOW(), INTERVAL 1 DAY), 1, 1 ),
				( "00:11:22:33:44:56", DATE_SUB(NOW(), INTERVAL 1 DAY), 1, 1 ),
				( "00:11:22:33:44:57", DATE_SUB(NOW(), INTERVAL 1 DAY), 1, 1 ),
				( "00:11:22:33:44:58", DATE_SUB(NOW(), INTERVAL 1 DAY), 1, 1 ),
				( "00:11:22:33:44:59", DATE_SUB(NOW(), INTERVAL 1 DAY), 1, 1 ),
				( "00:11:22:33:44:5a", DATE_SUB(NOW(), INTERVAL 1 DAY), 1, 1 ),
				( "00:11:22:33:44:5b", NOW(), 1, 1 ),
				( "00:11:22:33:44:5c", NOW(), 1, 1 ),
				( "00:11:22:33:44:5d", NOW(), 1, 1 ),
				( "00:11:22:33:44:5e", NOW(), 1, 1 ),
				( "00:11:22:33:44:5f", NOW(), 1, 1 ),
				( "00:11:22:33:44:54", NOW(), 1, 1 ),
				( "00:11:22:33:44:53", NOW(), 1, 1 ),
				( "00:11:22:33:44:52", NOW(), 1, 1 )
			   `,
		},
		0,
		[]sqlCountTest{
			{
				name:          "node_current_session entries left",
				sql:           ` SELECT COUNT(*) FROM node_current_session`,
				expectedCount: 8,
			},
		},
		[]string{
			"DELETE FROM node_current_session",
		},
	)
}
