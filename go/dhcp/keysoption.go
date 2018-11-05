package main

import (
	"github.com/inverse-inc/packetfence/go/log"
)

func MysqlInsert(key string, value string) bool {
	_, err := MySQLdatabase.Query("replace into key_value_storage values(?,?)", "/dhcpd/"+key, value)
	if err != nil {
		log.LoggerWContext(ctx).Error("Error while inserting into MySQL: " + err.Error())
		return false
	} else {
		return true
	}
}

func MysqlGet(key string) (string, string) {
	row, err := MySQLdatabase.Query("select id, value from key_value_storage where id = ?", "/dhcpd/"+key)
	if err != nil {
		log.LoggerWContext(ctx).Debug("Error while getting MySQL '" + key + "': " + err.Error())
		return "", ""
	}
	var (
		Id    string
		Value string
	)
	for row.Next() {
		err := row.Scan(&Id, &Value)
		if err != nil {
			log.LoggerWContext(ctx).Crit(err.Error())
		}
	}
	return Id, Value
}

func MysqlDel(key string) bool {
	_, err := MySQLdatabase.Query("delete from key_value_storage where id = ?", "/dhcpd/"+key)
	if err != nil {
		log.LoggerWContext(ctx).Error("Error while deleting MySQL key '" + key + "': " + err.Error())
		return false
	}
	return true
}
