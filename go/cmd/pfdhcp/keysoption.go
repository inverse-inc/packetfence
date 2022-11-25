package main

import (
	"net"
	"strconv"
	"time"

	dhcp "github.com/inverse-inc/dhcp4"
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
func MysqlSearchMac(sourceip string) (string, string, time.Time) {

	var keyConfNet pfconfigdriver.PfconfigKeys
	keyConfNet.PfconfigNS = "config::Network"
	keyConfNet.PfconfigHostnameOverlay = "yes"

	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfNet)
	var index int64
	var poolname string
	index = -1
	for _, key := range keyConfNet.Keys {
		var ConfNet pfconfigdriver.RessourseNetworkConf
		ConfNet.PfconfigHashNS = key
		pfconfigdriver.FetchDecodeSocket(ctx, &ConfNet)
		ip := net.ParseIP(ConfNet.Netmask)
		sz, _ := net.IPMask(ip.To4()).Size()
		cidr := strconv.Itoa(sz)
		_, subnet, _ := net.ParseCIDR(net.ParseIP(key).String() + "/" + cidr)
		if subnet.Contains(net.ParseIP(sourceip)) {
			index = IP4toInt(net.ParseIP(sourceip)) - IP4toInt(net.ParseIP(ConfNet.DhcpStart))
			poolname = key
			break
		}
	}
	if index != -1 {
		if err := MySQLdatabase.PingContext(ctx); err != nil {
			log.LoggerWContext(ctx).Error("Unable to ping database, reconnect: " + err.Error())
		}
		rows, err := MySQLdatabase.Query("select mac, released from dhcppool where pool_name = ? and idx = ?", poolname, index)
		defer rows.Close()
		if err != nil {
			log.LoggerWContext(ctx).Debug("Error while getting MySQL '" + poolname + "': " + err.Error())
			return FreeMac, "", time.Now()
		}
		var (
			mac      string
			released time.Time
		)
		for rows.Next() {
			err := rows.Scan(&mac, &released)
			if err != nil {
				log.LoggerWContext(ctx).Crit(err.Error())
				return FreeMac, "", time.Now()
			}
		}
		return mac, poolname, released
	}
	return FreeMac, "none", time.Now()
}

// MysqlSearchIp function
func MysqlSearchIP(sourcemac string) (string, string, time.Time) {
	if err := MySQLdatabase.PingContext(ctx); err != nil {
		log.LoggerWContext(ctx).Error("Unable to ping database, reconnect: " + err.Error())
	}
	rows, err := MySQLdatabase.Query("select pool_name, idx, released from dhcppool where mac = ?", sourcemac)
	defer rows.Close()
	if err != nil {
		log.LoggerWContext(ctx).Debug("Error while getting MySQL '" + sourcemac + "': " + err.Error())
		return FreeIP, "", time.Now()
	}
	var (
		pool_name string
		idx       int
		released  time.Time
	)
	for rows.Next() {
		err := rows.Scan(&pool_name, &idx, &released)
		if err != nil {
			log.LoggerWContext(ctx).Crit(err.Error())
			return FreeIP, "", time.Now()
		}
	}
	if pool_name != "" {
		var ConfNet pfconfigdriver.RessourseNetworkConf
		ConfNet.PfconfigHashNS = pool_name
		pfconfigdriver.FetchDecodeSocket(ctx, &ConfNet)
		ip := dhcp.IPAdd(net.ParseIP(ConfNet.DhcpStart), idx)
		return ip.String(), pool_name, released
	}
	return FreeIP, "", time.Now()
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
