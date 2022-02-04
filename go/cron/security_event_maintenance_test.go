package maint

import (
	"testing"
	"time"
)

func TestSecurityEventMaintenanceDelayed(t *testing.T) {
	testWindowSqlCleanup(
		t,
		"security_event_maintenance",
		map[string]interface{}{},
		[]string{
			`CREATE OR REPLACE TABLE security_event_maintenance_test_mac_delay
WITH first_mac AS (
    (
    SELECT
      LOWER(CONCAT_WS( ':', LPAD(HEX(((cur + 1) >> 40) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 32) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 24) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 16) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 8) & 255), 2, '0'), LPAD(HEX((cur + 1) & 255), 2, '0') )) AS mac, cur + 1 as start_int
    FROM
      (
        SELECT
          mac as cur_mac,
          CONV(REPLACE(mac, ':', ''), 16, 10) cur,
          CONV( REPLACE(IFNULL(LEAD(mac) OVER (
        ORDER BY
          mac), "ff:ff:ff:ff:ff:ff"), ':' , ''), 16, 10 ) as next
        FROM
          node
      )
      as x
    WHERE
      next - cur >= 100 LIMIT 1
    )
    UNION ALL
    (
        SELECT "00:00:00:00:00:01", 1
    )
    LIMIT 1
)

SELECT
    LOWER(CONCAT_WS(
        ':',
        LPAD(HEX(((seq + start_int) >> 40) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 32) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 24) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 16) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 8) & 255), 2, '0'),
        LPAD(HEX((seq + start_int) & 255), 2, '0')
    )) AS mac

FROM first_mac JOIN seq_0_to_49;`,
			`INSERT INTO node (tenant_id, mac) SELECT 1, mac FROM security_event_maintenance_test_mac_delay`,
			`INSERT INTO security_event (
                tenant_id,
                mac,
                security_event_id,
                start_date,
                release_date,
                status
            )
           SELECT
            1,
            mac,
            '1100017',
            DATE_SUB(NOW(), INTERVAL 1 HOUR),
            DATE_SUB(NOW(), INTERVAL 30 MINUTE),
            'delayed'
           FROM security_event_maintenance_test_mac_delay
            `,
		},
		2*time.Second,
		[]sqlCountTest{
			{
				"delayed switch to open",
				`SELECT COUNT(*) FROM security_event WHERE mac IN (SELECT mac from security_event_maintenance_test_mac_delay) AND status = 'open';`,
				50,
			},
		},
		[]string{
			`DELETE from node WHERE mac IN (SELECT mac FROM security_event_maintenance_test_mac_delay)`,
			`DROP TABLE IF EXISTS security_event_maintenance_test_mac_delay`,
		},
	)
}

func TestSecurityEventMaintenanceOpen(t *testing.T) {
	testWindowSqlCleanup(
		t,
		"security_event_maintenance",
		map[string]interface{}{},
		[]string{
			`CREATE OR REPLACE TABLE security_event_maintenance_test_mac_open
WITH first_mac AS (
    (
    SELECT
      LOWER(CONCAT_WS( ':', LPAD(HEX(((cur + 1) >> 40) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 32) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 24) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 16) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 8) & 255), 2, '0'), LPAD(HEX((cur + 1) & 255), 2, '0') )) AS mac, cur + 1 as start_int
    FROM
      (
        SELECT
          mac as cur_mac,
          CONV(REPLACE(mac, ':', ''), 16, 10) cur,
          CONV( REPLACE(IFNULL(LEAD(mac) OVER (
        ORDER BY
          mac), "ff:ff:ff:ff:ff:ff"), ':' , ''), 16, 10 ) as next
        FROM
          node
      )
      as x
    WHERE
      next - cur >= 100 LIMIT 1
    )
    UNION ALL
    (
        SELECT "00:00:00:00:00:01", 1
    )
    LIMIT 1
)

SELECT
    LOWER(CONCAT_WS(
        ':',
        LPAD(HEX(((seq + start_int) >> 40) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 32) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 24) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 16) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 8) & 255), 2, '0'),
        LPAD(HEX((seq + start_int) & 255), 2, '0')
    )) AS mac

FROM first_mac JOIN seq_0_to_99;`,
			`INSERT INTO node (tenant_id, mac) SELECT 1, mac FROM security_event_maintenance_test_mac_open`,
			`INSERT INTO security_event (
                tenant_id,
                mac,
                security_event_id,
                start_date,
                release_date,
                status
            )
           SELECT
            1,
            mac,
            '1100017',
            DATE_SUB(NOW(), INTERVAL 1 HOUR),
            DATE_SUB(NOW(), INTERVAL 30 MINUTE),
            'open'
           FROM security_event_maintenance_test_mac_open
            `,
		},
		2*time.Second,
		[]sqlCountTest{
			{
				"delayed switch to open",
				`SELECT COUNT(*) FROM security_event WHERE mac IN (SELECT mac from security_event_maintenance_test_mac_open) AND status = 'closed';`,
				100,
			},
		},
		[]string{
			`DELETE from node WHERE mac IN (SELECT mac FROM security_event_maintenance_test_mac_open)`,
			`DROP TABLE IF EXISTS security_event_maintenance_test_mac_open`,
		},
	)
}

func TestSecurityEventMaintenanceMixed(t *testing.T) {
	testWindowSqlCleanup(
		t,
		"security_event_maintenance",
		map[string]interface{}{},
		[]string{
			`
CREATE OR REPLACE TABLE security_event_maintenance_test_mac_mixed
WITH first_mac AS (
    (
    SELECT
      LOWER(CONCAT_WS( ':', LPAD(HEX(((cur + 1) >> 40) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 32) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 24) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 16) & 255), 2, '0'), LPAD(HEX(((cur + 1) >> 8) & 255), 2, '0'), LPAD(HEX((cur + 1) & 255), 2, '0') )) AS mac, cur + 1 as start_int
    FROM
      (
        SELECT
          mac as cur_mac,
          CONV(REPLACE(mac, ':', ''), 16, 10) cur,
          CONV( REPLACE(IFNULL(LEAD(mac) OVER (
        ORDER BY
          mac), "ff:ff:ff:ff:ff:ff"), ':' , ''), 16, 10 ) as next
        FROM
          node
      )
      as x
    WHERE
      next - cur >= 100 LIMIT 1
    )
    UNION ALL
    (
        SELECT "00:00:00:00:00:01", 1
    )
    LIMIT 1
)

SELECT
    LOWER(CONCAT_WS(
        ':',
        LPAD(HEX(((seq + start_int) >> 40) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 32) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 24) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 16) & 255), 2, '0'),
        LPAD(HEX(((seq + start_int) >> 8) & 255), 2, '0'),
        LPAD(HEX((seq + start_int) & 255), 2, '0')
    )) AS mac,
    ntile(4) over (order by mac) type

FROM first_mac JOIN seq_0_to_99;
            `,
			`INSERT INTO node (tenant_id, mac) SELECT 1, mac FROM security_event_maintenance_test_mac_mixed`,
			`INSERT INTO security_event (
                tenant_id,
                mac,
                security_event_id,
                start_date,
                release_date,
                status
            )
           SELECT
            1,
            mac,
            '1100017',
            DATE_SUB(NOW(), INTERVAL 1 HOUR),
            CASE type
            WHEN 1 THEN DATE_ADD(NOW(), INTERVAL 30 MINUTE)
            WHEN 3 THEN DATE_ADD(NOW(), INTERVAL 30 MINUTE)
            ELSE DATE_SUB(NOW(), INTERVAL 30 MINUTE)
            END,
            CASE type
            WHEN 1 THEN "delayed"
            WHEN 2 THEN "delayed"
            ELSE "open"
            END
           FROM security_event_maintenance_test_mac_mixed
            `,
		},
		2*time.Second,
		[]sqlCountTest{
			{
				"open to close",
				`SELECT COUNT(*) FROM security_event WHERE mac IN (SELECT mac from security_event_maintenance_test_mac_mixed WHERE type = 4) AND status = 'closed';`,
				25,
			},
			{
				"stayed open",
				`SELECT COUNT(*) FROM security_event WHERE mac IN (SELECT mac from security_event_maintenance_test_mac_mixed WHERE type = 3) AND status = 'open';`,
				25,
			},
			{
				"delay to open",
				`SELECT COUNT(*) FROM security_event WHERE mac IN (SELECT mac from security_event_maintenance_test_mac_mixed WHERE type = 2) AND status = 'open';`,
				25,
			},
			{
				"stayed delayed",
				`SELECT COUNT(*) FROM security_event WHERE mac IN (SELECT mac from security_event_maintenance_test_mac_mixed WHERE type = 1) AND status = 'delayed';`,
				25,
			},
		},
		[]string{
			`DELETE from node WHERE mac IN (SELECT mac FROM security_event_maintenance_test_mac_mixed)`,
            `DROP TABLE IF EXISTS security_event_maintenance_test_mac_mixed`,
		},
	)
}
