package maint

import (
	"context"
	"testing"
)

var jobsConfig = GetMaintenanceConfig(context.Background())

func testWindowSqlCleanup(t *testing.T, name string, additional_args map[string]interface{}, setupSql []string, tests []sqlCountTest, cleanupSQL []string) {
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
		tests,
		cleanupSQL,
	)
}

func TestAdminApiAuditLog(t *testing.T) {

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
		[]sqlCountTest{
			sqlCountTest{
				name:          "admin_api_audit_log entries left",
				sql:           ` SELECT COUNT(*) FROM admin_api_audit_log `,
				expectedCount: 8,
			},
		},
		[]string{"DELETE FROM admin_api_audit_log"},
	)
}

func TestAuthLog(t *testing.T) {

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
		[]sqlCountTest{
			sqlCountTest{
				name:          "auth_log entries left",
				sql:           ` SELECT COUNT(*) FROM auth_log `,
				expectedCount: 8,
			},
		},
		[]string{"DELETE FROM auth_log"},
	)
}

func TestDnsAuditLog(t *testing.T) {

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
		[]sqlCountTest{
			sqlCountTest{
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
		[]sqlCountTest{
			sqlCountTest{
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
		[]sqlCountTest{
			sqlCountTest{
				name:          "locationlog entries left",
				sql:           ` SELECT COUNT(*) FROM locationlog `,
				expectedCount: 8,
			},
			sqlCountTest{
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
		[]sqlCountTest{
			sqlCountTest{
				name:          "radacct entries left",
				sql:           ` SELECT COUNT(*) FROM radacct `,
				expectedCount: 8,
			},
			sqlCountTest{
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

func TestBandwidthMaintenanceSession(t *testing.T) {
	testWindowSqlCleanup(
		t,
		"bandwidth_maintenance_session",
		map[string]interface{}{
			"timeout": 1000.0,
			"batch":   100.0,
			"window":  float64(12 * 60 * 60),
		},
		[]string{
			"DELETE FROM bandwidth_accounting",
			`
INSERT INTO bandwidth_accounting (
        tenant_id,
        node_id,
        unique_session_id,
        mac,
        time_bucket,
        in_bytes,
        out_bytes,
        last_updated,
        source_type
) WITH macs AS (
    SELECT
        (1 << 48 | seq) as node_id,
        LOWER(CONCAT_WS(
            ':',
            LPAD(HEX((seq >> 40) & 255), 2, '0'),
            LPAD(HEX((seq >> 32) & 255), 2, '0'),
            LPAD(HEX((seq >> 24) & 255), 2, '0'),
            LPAD(HEX((seq >> 16) & 255), 2, '0'),
            LPAD(HEX((seq >> 8) & 255), 2, '0'),
            LPAD(HEX(seq & 255), 2, '0')
        )) AS mac FROM seq_1_to_20
), dates AS (
    SELECT seq as session_id, DATE_SUB(DATE_SUB(NOW(), INTERVAL 2 DAY), INTERVAL seq * 15 MINUTE ) as time_bucket from seq_0_to_359
)

SELECT
    1 AS tenant_id,
    node_id,
    session_id,
    mac,
    time_bucket,
    100 in_bytes,
    100 out_bytes,
    time_bucket as last_updated,
    'radius' as source_type
FROM macs JOIN dates;
            `,
		},
		[]sqlCountTest{
			sqlCountTest{
				name:          "bandwidth_accounting marked done",
				sql:           `SELECT COUNT(*) FROM bandwidth_accounting WHERE last_updated = '0000-00-00 00:00:00'`,
				expectedCount: 7200,
			},
		},
		[]string{
			"DELETE FROM bandwidth_accounting",
		},
	)

	testWindowSqlCleanup(
		t,
		"bandwidth_maintenance_session",
		map[string]interface{}{
			"timeout": 1000.0,
			"batch":   100.0,
			"window":  float64(25 * 60 * 60),
		},
		[]string{
			"DELETE FROM bandwidth_accounting",
			`
INSERT INTO bandwidth_accounting (
        tenant_id,
        node_id,
        unique_session_id,
        mac,
        time_bucket,
        in_bytes,
        out_bytes,
        last_updated,
        source_type
) WITH macs AS (
    SELECT
        (1 << 48 | seq) as node_id,
        LOWER(CONCAT_WS(
            ':',
            LPAD(HEX((seq >> 40) & 255), 2, '0'),
            LPAD(HEX((seq >> 32) & 255), 2, '0'),
            LPAD(HEX((seq >> 24) & 255), 2, '0'),
            LPAD(HEX((seq >> 16) & 255), 2, '0'),
            LPAD(HEX((seq >> 8) & 255), 2, '0'),
            LPAD(HEX(seq & 255), 2, '0')
        )) AS mac FROM seq_1_to_20
), dates AS (
    SELECT seq as session_id, DATE_SUB(NOW(), INTERVAL seq * 15 MINUTE ) as time_bucket from seq_0_to_95
)

SELECT
    1 AS tenant_id,
    node_id,
    session_id,
    mac,
    time_bucket,
    100 in_bytes,
    100 out_bytes,
    time_bucket as last_updated,
    'radius' as source_type
FROM macs JOIN dates;
            `,
		},
		[]sqlCountTest{
			sqlCountTest{
				name:          "bandwidth_accounting marked done",
				sql:           `SELECT COUNT(*) FROM bandwidth_accounting WHERE last_updated != '0000-00-00 00:00:00'`,
				expectedCount: 1920,
			},
		},
		[]string{
			"DELETE FROM bandwidth_accounting",
		},
	)

}
