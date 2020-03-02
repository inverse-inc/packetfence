package main

import (
	"context"
	"database/sql"
	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/packetfence/go/db"
	"time"
)

const DefaultTimeDuration = 5 * time.Minute

type PfAcct struct {
	Db           *sql.DB
	TimeDuration time.Duration
	RadiusStatements
}

func NewPfAcct() *PfAcct {
	var ctx = context.Background()
	db, err := db.DbFromConfig(ctx)
	if err != nil {
		return nil
	}

	pfAcct := &PfAcct{Db: db, TimeDuration: DefaultTimeDuration}
	pfAcct.RadiusStatements.Setup(pfAcct.Db)
	return pfAcct
}
