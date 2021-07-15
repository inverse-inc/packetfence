package mariadb

import (
	"context"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path"
	"regexp"
	"strconv"
	"strings"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

const RunningSeqno = -1
const DefaultSeqno = -2

const GaleraAutofixSeqnoFile = "/var/lib/mysql/galera-autofix-seqno.dat"

var databaseConf = pfconfigdriver.PfConfDatabase{}

func DatabaseConfig(ctx context.Context) pfconfigdriver.PfConfDatabase {
	pfconfigdriver.FetchDecodeSocketCache(ctx, &databaseConf)
	return databaseConf
}

func ForceStop(ctx context.Context) error {
	err := exec.Command(`systemctl`, `stop`, `packetfence-mariadb`).Run()
	if err != nil {
		log.LoggerWContext(ctx).Error("Failed to stop the MariaDB service via systemctl: " + err.Error())
		return err
	}

	exec.Command(`pkill`, `-9`, `-f`, `mysqld`).Run()
	exec.Command(`pkill`, `-9`, `-f`, `socat`).Run()

	return nil
}

func ClearAndStart(ctx context.Context) error {
	dir, err := ioutil.ReadDir("/var/lib/mysql")
	if err != nil {
		log.LoggerWContext(ctx).Error("Failed to list the /var/lib/mysql/ directory: " + err.Error())
		return err
	}
	for _, d := range dir {
		err := os.RemoveAll(path.Join([]string{"/var/lib/mysql", d.Name()}...))
		if err != nil {
			log.LoggerWContext(ctx).Error("Failed to empty the /var/lib/mysql/ directory: " + err.Error())
			return err
		}
	}

	return Start(ctx)
}

func Start(ctx context.Context) error {
	err := exec.Command(`systemctl`, `start`, `packetfence-mariadb`).Run()
	if err != nil {
		log.LoggerWContext(ctx).Error("Failed to start packetfence-mariadb: " + err.Error())
		return err
	}

	return nil
}

func StartNewCluster(ctx context.Context) error {
	defer func() {
		err := exec.Command(`systemctl`, `unset-environment`, `MARIADB_ARGS`).Run()
		if err != nil {
			log.LoggerWContext(ctx).Error("Failed to unset the MARIADB_ARGS environment variable in systemctl" + err.Error())
		}
	}()

	err := exec.Command(`systemctl`, `set-environment`, `MARIADB_ARGS=--force-new-cluster`).Run()
	if err != nil {
		log.LoggerWContext(ctx).Error("Failed to set the MARIADB_ARGS environment variable in systemctl" + err.Error())
		return err
	}

	err = exec.Command(`systemctl`, `start`, `packetfence-mariadb.service`).Run()
	if err != nil {
		log.LoggerWContext(ctx).Error("Failed to start packetfence-mariadb in force new cluster mode: " + err.Error())
		return err
	}

	return nil
}

func WsrepRecover(ctx context.Context) error {
	err := exec.Command(`mysqld_safe`, `--defaults-file=/usr/local/pf/var/conf/mariadb.conf`, `--wsrep-recover`).Run()
	if err != nil {
		log.LoggerWContext(ctx).Error("Unable to perform wsrep-recover: " + err.Error())
		return err
	}

	return nil
}

func GetColdSeqno(ctx context.Context) (int, error) {
	data, err := ioutil.ReadFile(GaleraAutofixSeqnoFile)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Unable to get cold sequence number from %s: %s", GaleraAutofixSeqnoFile, err.Error()))
		return DefaultSeqno, err
	}

	seqno, err := strconv.Atoi(string(data))
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Unable to convert recorded sequence number '%s' to an int: %s", data, err.Error()))
		return DefaultSeqno, err
	}

	return seqno, nil
}

func IsLocalDBAvailable(ctx context.Context) bool {
	return IsDBAvailable(ctx, "localhost")
}

func GetLocalLiveSeqno(ctx context.Context) int {
	return GetLiveSeqno(ctx, "localhost")
}

func GetLiveSeqno(ctx context.Context, host string) int {
	ctx = log.AddToLogContext(ctx, "function", "GetLiveSeqno")
	conf := DatabaseConfig(ctx)
	db, err := db.ManualConnectDb(ctx, conf.User, conf.Pass, host, conf.Db)
	if err != nil {
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("Unable to connect to database on %s : %s", host, err.Error()))
		return DefaultSeqno
	}
	defer db.Close()
	rows, err := db.Query("show status like 'wsrep_last_committed'")
	if err != nil {
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("Unable to connect to database on %s : %s", host, err.Error()))
		return DefaultSeqno
	}
	defer rows.Close()
	for rows.Next() {
		var name string
		var lastCommitted int
		if err := rows.Scan(&name, &lastCommitted); err != nil {
			log.LoggerWContext(ctx).Warn(fmt.Sprintf("Unable to connect to database on %s : %s", host, err.Error()))
			return DefaultSeqno
		}
		return lastCommitted
	}
	log.LoggerWContext(ctx).Warn(fmt.Sprintf("Unable to connect to database on %s : %s", host, err.Error()))
	return DefaultSeqno
}

func IsDBAvailable(ctx context.Context, host string) bool {
	ctx = log.AddToLogContext(ctx, "function", "IsDBAvailable")
	conf := DatabaseConfig(ctx)
	db, err := db.ManualConnectDb(ctx, conf.User, conf.Pass, host, conf.Db)
	if err != nil {
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("Unable to connect to database on %s : %s", host, err.Error()))
		return false
	}
	defer db.Close()
	rows, err := db.Query("show status like 'wsrep_cluster_status'")
	if err != nil {
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("Unable to connect to database on %s : %s", host, err.Error()))
		return false
	}
	defer rows.Close()
	for rows.Next() {
		var name string
		var status string
		if err := rows.Scan(&name, &status); err != nil {
			log.LoggerWContext(ctx).Warn(fmt.Sprintf("Unable to connect to database on %s : %s", host, err.Error()))
			return false
		}
		if status == "Primary" {
			return true
		} else {
			log.LoggerWContext(ctx).Warn(fmt.Sprintf("Unable to connect to database on %s : status is not Primary", host))
			return false
		}
	}
	log.LoggerWContext(ctx).Warn(fmt.Sprintf("Unable to connect to database on %s : %s", host, err.Error()))
	return false
}

func IsActive(ctx context.Context) bool {
	cmd := exec.Command(`systemctl`, `is-active`, `packetfence-mariadb`)
	out, _ := cmd.Output()
	outStr := strings.TrimSuffix(string(out), "\n")
	if matched, _ := regexp.MatchString(`^activ`, outStr); matched {
		log.LoggerWContext(ctx).Info("packetfence-mariadb is currently in a state considered active on this node: " + outStr)
		return true
	} else {
		log.LoggerWContext(ctx).Info("packetfence-mariadb is currently in a state considered inactive on this node: " + outStr)
		return false
	}
}
