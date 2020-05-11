package maint

import (
	"database/sql"
	"github.com/inverse-inc/packetfence/go/tryableonce"
)

type StmtSetup struct {
	stmt     *sql.Stmt
	stmtOnce tryableonce.TryableOnce
}

func (s *StmtSetup) Stmt(sql string) *sql.Stmt {
	err := s.stmtOnce.Do(
		func() error {
			db, err := getDb()
			if err != nil {
				return err
			}
			s.stmt, err = db.Prepare(sql)
			if err != nil {
				return err
			}

			return nil
		},
	)

	if err != nil {
		return nil
	}

	return s.stmt
}
