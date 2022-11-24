package main

import (
	"net"
	"strconv"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// MysqlInsert function
func MysqlInsert(key string, value string) bool {
	if err := MySQLdatabase.PingContext(ctx); err != nil {
		log.LoggerWContext(ctx).Error("Unable to ping database, reconnect: " + err.Error())
	}
	rows, err := MySQLdatabase.Query("replace into key_value_storage values(?,?)", "/dhcpd/"+key, value)
	defer rows.Close()
	if err != nil {
		log.LoggerWContext(ctx).Error("Error while inserting into MySQL: " + err.Error())
		return false
	}
	return true
}

// MysqlGet function
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

// MysqlSearchMac function
func MysqlSearchMac(key string) string {

	var keyConfNet pfconfigdriver.PfconfigKeys
	keyConfNet.PfconfigNS = "config::Network"
	keyConfNet.PfconfigHostnameOverlay = "yes"

	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfNet)
	var index int64
	index = -1
	for _, key := range keyConfNet.Keys {
		var ConfNet pfconfigdriver.RessourseNetworkConf
		ConfNet.PfconfigHashNS = key
		pfconfigdriver.FetchDecodeSocket(ctx, &ConfNet)
		ip := net.ParseIP(ConfNet.Netmask)
		sz, _ := net.IPMask(ip.To4()).Size()
		cidr := strconv.Itoa(sz)
		_, subnet, _ := net.ParseCIDR(net.ParseIP(key).String() + "/" + cidr)
		if subnet.Contains(net.ParseIP(key)) {
			index = IP4toInt(net.ParseIP(key)) - IP4toInt(net.ParseIP(ConfNet.DhcpStart))
			break
		}
	}
	if index != -1 {
		if err := MySQLdatabase.PingContext(ctx); err != nil {
			log.LoggerWContext(ctx).Error("Unable to ping database, reconnect: " + err.Error())
		}
		rows, err := MySQLdatabase.Query("select mac from dhcppool where pool_name = ? and idx = ?", key, index)
		defer rows.Close()
		if err != nil {
			log.LoggerWContext(ctx).Debug("Error while getting MySQL '" + key + "': " + err.Error())
			return ""
		}
		var (
			mac string
		)
		for rows.Next() {
			err := rows.Scan(&mac)
			if err != nil {
				log.LoggerWContext(ctx).Crit(err.Error())
				return ""
			}
		}
		return mac
	}
	return FreeMac
}

// MysqlDel function
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
