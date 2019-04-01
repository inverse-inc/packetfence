package main

import (
	"github.com/inverse-inc/packetfence/go/log"
)

func MysqlInsert(key string, value string) bool {
	if err := MySQLdatabase.PingContext(ctx); err != nil {
		log.LoggerWContext(ctx).Error("Unable to ping database, reconnect: " + err.Error())
	}
	rows, err := MySQLdatabase.Query("replace into key_value_storage values(?,?)", "/dhcpd/"+key, value)
	defer rows.Close()
	if err != nil {
		log.LoggerWContext(ctx).Error("Error while inserting into MySQL: " + err.Error())
		return false
	} else {
		return true
	}
}

func MysqlGet(key string) (string, string) {
	if err := MySQLdatabase.PingContext(ctx); err != nil {
		log.LoggerWContext(ctx).Error("Unable to ping database, reconnect: " + err.Error())
	}
	rows, err := MySQLdatabase.Query("select id, value from key_value_storage where id = ?", "/dhcpd/"+key)
	defer rows.Close()
	if err != nil {
		log.LoggerWContext(ctx).Debug("Error while getting MySQL '" + key + "': " + err.Error())
		return "", ""
	}
	var (
		Id    string
		Value string
	)
	for rows.Next() {
		err := rows.Scan(&Id, &Value)
		if err != nil {
			log.LoggerWContext(ctx).Crit(err.Error())
		}
	}
	return Id, Value
}

func MysqlDel(key string) bool {
	if err := MySQLdatabase.PingContext(ctx); err != nil {
		log.LoggerWContext(ctx).Error("Unable to ping database, reconnect: " + err.Error())
	}
	rows, err := MySQLdatabase.Query("delete from key_value_storage where id = ?", "/dhcpd/"+key)
	defer rows.Close()
	if err != nil {
		log.LoggerWContext(ctx).Error("Error while deleting MySQL key '" + key + "': " + err.Error())
		return false
	}
	return true
}
