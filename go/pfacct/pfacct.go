package main

import (
	"context"
	"database/sql"
	"github.com/inverse-inc/packetfence/go/db"
)

type PfAcct struct {
	Db *sql.DB
}

func NewPfAcct() *PfAcct {
	var ctx = context.Background()
	db, err := db.DbFromConfig(ctx)
	if err != nil {
		return nil
	}

	return &PfAcct{Db: db}
}
