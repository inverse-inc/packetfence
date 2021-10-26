package maint

import (
	"testing"
)

func TestBandwidthMaintenanceNetFlow(t *testing.T) {
	testWindowSqlCleanup(
		t,
		"bandwidth_maintenance",
		nil,
		[]string{
			"DELETE FROM bandwidth_accounting",
			"DELETE FROM bandwidth_accounting_history",
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
    'net_flow' as source_type
FROM macs JOIN dates;
`,
		},
		[]sqlCountTest{
			{
				name:          "bandwidth just keep the last 2hrs",
				sql:           `SELECT COUNT(*) FROM bandwidth_accounting`,
				expectedCount: 20,
			},
			{
				name:          "bandwidth was kept in bandwidth_accounting",
				sql:           `SELECT COUNT( DISTINCT node_id) FROM bandwidth_accounting`,
				expectedCount: 20,
			},
			{
				name:          "bandwidth was moved to the history table",
				sql:           `SELECT COUNT( DISTINCT node_id) FROM bandwidth_accounting_history`,
				expectedCount: 20,
			},
			{
				name: "bandwidth merged",
				sql: `
                SELECT COUNT(*) FROM (
                    SELECT SUM(in_bytes) as in_bytes, node_id FROM (
                        SELECT node_id, SUM(in_bytes) as in_bytes FROM bandwidth_accounting_history GROUP BY node_id
                        UNION ALL
                        SELECT node_id, SUM(in_bytes) as in_bytes FROM bandwidth_accounting GROUP BY node_id
                    ) as y GROUP BY node_id
                ) as x WHERE in_bytes = 9600`,
				expectedCount: 20,
			},
		},
		[]string{
			"DELETE FROM bandwidth_accounting",
			"DELETE FROM bandwidth_accounting_history",
        },
	)
}

func TestBandwidthMaintenanceAggregation(t *testing.T) {
	testWindowSqlCleanup(
		t,
		"bandwidth_maintenance",
		nil,
		[]string{
			"DELETE FROM bandwidth_accounting",
			"DELETE FROM bandwidth_accounting_history",
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
    '0000-00-00 00:00:00' as last_updated,
    'radius' as source_type
FROM macs JOIN dates;
`,
		},
		[]sqlCountTest{
			{
				name:          "bandwidth just keep the last 2hrs",
				sql:           `SELECT COUNT(*) FROM bandwidth_accounting`,
				expectedCount: 160,
			},
			{
				name:          "bandwidth was kept in bandwidth_accounting",
				sql:           `SELECT COUNT(DISTINCT node_id) FROM bandwidth_accounting`,
				expectedCount: 20,
			},
			{
				name:          "bandwidth was moved to the history table",
				sql:           `SELECT COUNT(DISTINCT node_id) FROM bandwidth_accounting_history`,
				expectedCount: 20,
			},
			{
				name: "bandwidth merged",
				sql: `
                SELECT COUNT(*) FROM (
                    SELECT SUM(in_bytes) as in_bytes, node_id FROM (
                        SELECT node_id, SUM(in_bytes) as in_bytes FROM bandwidth_accounting_history GROUP BY node_id
                        UNION ALL
                        SELECT node_id, SUM(in_bytes) as in_bytes FROM bandwidth_accounting GROUP BY node_id
                    ) as y GROUP BY node_id
                ) as x WHERE in_bytes = 9600`,
				expectedCount: 20,
			},
		},
		[]string{
        },
	)
}
