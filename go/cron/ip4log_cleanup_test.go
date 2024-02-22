package maint

import (
	"testing"
	"time"
)

func TestIp4logCleanupNoRotate(t *testing.T) {

	testCronTask(
		t,
		&Ip4logCleanup{
			Task: Task{
				Type:            "ip4log_cleanup",
				Status:          "enabled",
				Description:     "Test",
				ScheduleSpecStr: "@every 1m",
			},
			Window:        12 * 60 * 60,
			Batch:         100,
			Timeout:       10,
			RotateTimeout: 10,
			RotateWindow:  24 * 60 * 60,
			Rotate:        "N",
		},
		[]string{
			"DELETE FROM ip4log_history",
			`
     INSERT INTO ip4log_history (mac, ip, start_time, end_time) VALUES
("88:15:44:04:bd:56", "172.20.20.150", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("56:72:a6:73:82:52", "172.20.20.196", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("3c:bd:3e:70:cb:8c", "172.20.20.241", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("f4:5c:89:b0:59:3b", "172.20.20.50",  DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("7c:2a:31:4c:cb:f6", "172.20.20.53",  DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("9c:b6:d0:8b:e5:db", "172.20.20.67",  DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("3c:22:fb:b8:46:df", "172.20.21.119", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("7c:2a:31:4c:cb:f6", "172.20.21.152", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("3c:22:fb:b8:1a:37", "172.20.21.154", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("7c:2a:31:4c:cb:f6", "172.20.21.170", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("7c:2a:31:4c:cb:f6", "172.20.21.173", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("00:0c:29:04:c9:e7", "172.20.21.186", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("10:5b:ad:4a:28:a6", "172.20.21.233", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("82:59:26:37:77:72", "172.20.21.90",  DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() )
            `,
		},
		0,
		[]sqlCountTest{
			{
				name: "ip4log_history entries gone",
				sql: `
                    SELECT
                        COUNT(*) FROM ip4log_history
                    WHERE
                        ip IN (
                            "172.20.20.50",
                            "172.20.20.53",
                            "172.20.21.119",
                            "172.20.21.154",
                            "172.20.21.170",
                            "172.20.21.173"
                        )
                `,
				expectedCount: 0,
			},
			{
				name: "ip4log_history entries kept",
				sql: `
                    SELECT
                        COUNT(*) FROM ip4log_history
                    WHERE
                        ip NOT IN (
                            "172.20.20.50",
                            "172.20.20.53",
                            "172.20.21.119",
                            "172.20.21.154",
                            "172.20.21.170",
                            "172.20.21.173"
                        )
                `,
				expectedCount: 8,
			},
		},
		[]string{"DELETE FROM ip4log_history"},
	)

}

func TestIp4logCleanupRotate(t *testing.T) {

	testCronTask(
		t,
		&Ip4logCleanup{
			Task: Task{
				Type:            "ip4log_cleanup",
				Status:          "enabled",
				Description:     "Test",
				ScheduleSpecStr: "@every 1m",
			},
			Window:        25 * 60 * 60,
			Batch:         100,
			Timeout:       10,
			RotateTimeout: 10,
			RotateBatch:   100,
			RotateWindow:  12 * 60 * 60,
			Rotate:        "Y",
		},
		[]string{
			"DELETE FROM ip4log_history",
			"DELETE FROM ip4log_archive",
			`
     INSERT INTO ip4log_history (mac, ip, start_time, end_time) VALUES
("88:15:44:04:bd:56", "172.20.20.150", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("56:72:a6:73:82:52", "172.20.20.196", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("3c:bd:3e:70:cb:8c", "172.20.20.241", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("f4:5c:89:b0:59:3b", "172.20.20.50",  DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("7c:2a:31:4c:cb:f6", "172.20.20.53",  DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("9c:b6:d0:8b:e5:db", "172.20.20.67",  DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("3c:22:fb:b8:46:df", "172.20.21.119", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("7c:2a:31:4c:cb:f6", "172.20.21.152", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("3c:22:fb:b8:1a:37", "172.20.21.154", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("7c:2a:31:4c:cb:f6", "172.20.21.170", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("7c:2a:31:4c:cb:f6", "172.20.21.173", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("00:0c:29:04:c9:e7", "172.20.21.186", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("10:5b:ad:4a:28:a6", "172.20.21.233", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("82:59:26:37:77:72", "172.20.21.90",  DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() )
            `,
		},
		0,
		[]sqlCountTest{
			{
				name: "ip4log_history entries gone",
				sql: `
                    SELECT
                        COUNT(*) FROM ip4log_history
                    WHERE
                        ip IN (
                            "172.20.20.50",
                            "172.20.20.53",
                            "172.20.21.119",
                            "172.20.21.154",
                            "172.20.21.170",
                            "172.20.21.173"
                        )
                `,
				expectedCount: 0,
			},
			{
				name:          "ip4log_history entries kept",
				sql:           ` SELECT COUNT(*) FROM ip4log_history `,
				expectedCount: 8,
			},
			{
				name:          "ip4log_archive created",
				sql:           `SELECT COUNT(*) FROM ip4log_archive`,
				expectedCount: 6,
			},
		},
		[]string{
			"DELETE FROM ip4log_history",
			"DELETE FROM ip4log_archive",
		},
	)

}

func testCronTask(t *testing.T, job JobSetupConfig, setupSql []string, pause time.Duration, tests []sqlCountTest, cleanupSql []string) {
	runStatements(t, setupSql)
	job.Run()
	if pause > 0 {
		time.Sleep(pause)
	}
	testSqlCountTests(t, tests)
	runStatements(t, cleanupSql)
}
