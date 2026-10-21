package main

import (
	"context"
	"database/sql"
	"time"

	"github.com/inverse-inc/go-utils/log"
)

// MysqlInsert function
func MysqlInsert(ctx context.Context, key string, value string, db *sql.DB) bool {
	dbCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := db.PingContext(dbCtx); err != nil {
		log.LoggerWContext(ctx).Error("Unable to ping database, reconnect: " + err.Error())
	}
	_, err := db.ExecContext(dbCtx,

		`
INSERT into key_value_storage values(?,?)
ON DUPLICATE KEY UPDATE value = VALUES(value)
		`,
		"/dhcpd/"+key,
		value,
	)

	if err != nil {
		log.LoggerWContext(ctx).Error("Error while inserting into MySQL: " + err.Error())
		return false
	}

	return true
}

// MysqlGet function
func MysqlGet(ctx context.Context, key string, db *sql.DB) (string, string) {
	dbCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := db.PingContext(dbCtx); err != nil {
		log.LoggerWContext(ctx).Error("Unable to ping database, reconnect: " + err.Error())
	}

	rows, err := db.QueryContext(dbCtx, "select id, value from key_value_storage where id = ?", "/dhcpd/"+key)
	if err != nil {
		log.LoggerWContext(ctx).Debug("Error while getting MySQL '" + key + "': " + err.Error())
		return "", ""
	}
	defer rows.Close()
	var (
		ID    string
		Value string
	)
	for rows.Next() {
		err := rows.Scan(&ID, &Value)
		if err != nil {
			log.LoggerWContext(ctx).Crit(err.Error())
		}
	}
	return ID, Value
}

// MysqlDel function
func MysqlDel(key string, db *sql.DB) bool {
	dbCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := db.PingContext(dbCtx); err != nil {
		log.LoggerWContext(ctx).Error("Unable to ping database, reconnect: " + err.Error())
	}
	_, err := db.ExecContext(dbCtx, "delete from key_value_storage where id = ?", "/dhcpd/"+key)
	if err != nil {
		log.LoggerWContext(ctx).Error("Error while deleting MySQL key '" + key + "': " + err.Error())
		return false
	}
	return true
}
