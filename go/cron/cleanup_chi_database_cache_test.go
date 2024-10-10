package maint

import (
	"testing"
)

func TestChiCleanup(t *testing.T) {
	testWindowSqlCleanup(
		t,
		"cleanup_chi_database_cache",
		map[string]interface{}{
			"timeout": 10.0,
			"batch":   100.0,
		},
		[]string{
			"DELETE FROM chi_cache",
			"INSERT INTO chi_cache (`key`, expires_at) VALUES" + `
        ( "0", UNIX_TIMESTAMP(DATE_ADD(NOW(), INTERVAL 1 DAY)) * 1.0 ),
        ( "1", UNIX_TIMESTAMP(DATE_ADD(NOW(), INTERVAL 1 DAY)) * 1.0 ),
        ( "2", UNIX_TIMESTAMP(DATE_ADD(NOW(), INTERVAL 1 DAY)) * 1.0 ),
        ( "3", UNIX_TIMESTAMP(DATE_ADD(NOW(), INTERVAL 1 DAY)) * 1.0 ),
        ( "4", UNIX_TIMESTAMP(DATE_ADD(NOW(), INTERVAL 1 DAY)) * 1.0 ),
        ( "5", UNIX_TIMESTAMP(DATE_ADD(NOW(), INTERVAL 1 DAY)) * 1.0 ),
        ( "6", UNIX_TIMESTAMP(DATE_ADD(NOW(), INTERVAL 1 DAY)) * 1.0 ),
        ( "7", UNIX_TIMESTAMP(DATE_ADD(NOW(), INTERVAL 1 DAY)) * 1.0 ),
        ( "8", UNIX_TIMESTAMP(DATE_ADD(NOW(), INTERVAL 1 DAY)) * 1.0 ),
        ( "9", UNIX_TIMESTAMP(DATE_ADD(NOW(), INTERVAL 1 DAY)) * 1.0 ),
        ( "a", UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 1 DAY)) * 1.0 ),
        ( "b", UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 1 DAY)) * 1.0 ),
        ( "c", UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 1 DAY)) * 1.0 ),
        ( "d", UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 1 DAY)) * 1.0 ),
        ( "e", UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 1 DAY)) * 1.0 ),
        ( "f", UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 1 DAY)) * 1.0 )
            `,
		},
		0,
		[]sqlCountTest{
			{
				name:          "chi_cache entries left",
				sql:           ` SELECT COUNT(*) FROM chi_cache `,
				expectedCount: 10,
			},
		},
		[]string{"DELETE FROM chi_cache"},
	)
}
