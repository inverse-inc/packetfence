package maint

import (
	"testing"
)

func TestIp6logCleanupNoRotate(t *testing.T) {

	testCronTask(
		t,
		&Ip6logCleanup{
			Task: Task{
				Type:            "ip6log_cleanup",
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
			"DELETE FROM ip6log_history",
			`
INSERT INTO ip6log_history (mac, ip, start_time, end_time) VALUES
    ("3c:22:fb:b8:1a:37", "2001:0db8:85a3:0000:0000:8a2e:0370:7338", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
    ("7c:2a:31:4c:cb:f6", "2001:0db8:85a3:0000:0000:8a2e:0370:7339", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
    ("7c:2a:31:4c:cb:f6", "2001:0db8:85a3:0000:0000:8a2e:0370:733a", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
    ("f4:5c:89:b0:59:3b", "2001:0db8:85a3:0000:0000:8a2e:0370:7333", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
    ("7c:2a:31:4c:cb:f6", "2001:0db8:85a3:0000:0000:8a2e:0370:7334", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
    ("3c:22:fb:b8:46:df", "2001:0db8:85a3:0000:0000:8a2e:0370:7336", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
    ("88:15:44:04:bd:56", "2001:0db8:85a3:0000:0000:8a2e:0370:7330", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
    ("56:72:a6:73:82:52", "2001:0db8:85a3:0000:0000:8a2e:0370:7331", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
    ("3c:bd:3e:70:cb:8c", "2001:0db8:85a3:0000:0000:8a2e:0370:7332", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
    ("9c:b6:d0:8b:e5:db", "2001:0db8:85a3:0000:0000:8a2e:0370:7335", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
    ("7c:2a:31:4c:cb:f6", "2001:0db8:85a3:0000:0000:8a2e:0370:7337", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
    ("00:0c:29:04:c9:e7", "2001:0db8:85a3:0000:0000:8a2e:0370:733b", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
    ("10:5b:ad:4a:28:a6", "2001:0db8:85a3:0000:0000:8a2e:0370:733c", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
    ("82:59:26:37:77:72", "2001:0db8:85a3:0000:0000:8a2e:0370:733d", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() )
`,
		},
		0,
		[]sqlCountTest{
			{
				name:          "ip6log_history entries kept",
				sql:           "SELECT COUNT(*) FROM ip6log_history",
				expectedCount: 8,
			},
		},
		[]string{"DELETE FROM ip6log_history"},
	)

}

func TestIp6logCleanupRotate(t *testing.T) {

	testCronTask(
		t,
		&Ip6logCleanup{
			Task: Task{
				Type:            "ip6log_cleanup",
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
			"DELETE FROM ip6log_history",
			"DELETE FROM ip6log_archive",
			`
     INSERT INTO ip6log_history (mac, ip, start_time, end_time) VALUES
("88:15:44:04:bd:56", "2001:0db8:85a3:0000:0000:8a2e:0370:7330", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("56:72:a6:73:82:52", "2001:0db8:85a3:0000:0000:8a2e:0370:7331", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("3c:bd:3e:70:cb:8c", "2001:0db8:85a3:0000:0000:8a2e:0370:7332", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("f4:5c:89:b0:59:3b", "2001:0db8:85a3:0000:0000:8a2e:0370:7333", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("7c:2a:31:4c:cb:f6", "2001:0db8:85a3:0000:0000:8a2e:0370:7334", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("9c:b6:d0:8b:e5:db", "2001:0db8:85a3:0000:0000:8a2e:0370:7335", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("3c:22:fb:b8:46:df", "2001:0db8:85a3:0000:0000:8a2e:0370:7336", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("7c:2a:31:4c:cb:f6", "2001:0db8:85a3:0000:0000:8a2e:0370:7337", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("3c:22:fb:b8:1a:37", "2001:0db8:85a3:0000:0000:8a2e:0370:7338", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("7c:2a:31:4c:cb:f6", "2001:0db8:85a3:0000:0000:8a2e:0370:7339", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("7c:2a:31:4c:cb:f6", "2001:0db8:85a3:0000:0000:8a2e:0370:733a", DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY) ),
("00:0c:29:04:c9:e7", "2001:0db8:85a3:0000:0000:8a2e:0370:733b", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("10:5b:ad:4a:28:a6", "2001:0db8:85a3:0000:0000:8a2e:0370:733c", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() ),
("82:59:26:37:77:72", "2001:0db8:85a3:0000:0000:8a2e:0370:733d", DATE_SUB(NOW(), INTERVAL 2 DAY), NOW() )
            `,
		},
		0,
		[]sqlCountTest{
			{
				name:          "ip6log_history entries kept",
				sql:           ` SELECT COUNT(*) FROM ip6log_history `,
				expectedCount: 8,
			},
			{
				name:          "ip6log_archive created",
				sql:           `SELECT COUNT(*) FROM ip6log_archive`,
				expectedCount: 6,
			},
		},
		[]string{
			"DELETE FROM ip6log_history",
			"DELETE FROM ip6log_archive",
		},
	)

}
