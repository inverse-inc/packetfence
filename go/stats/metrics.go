package main

import (
	"context"
	"database/sql"

	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/packetfence/go/interval"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

var MySQLdatabase *sql.DB

func ProcessMetricConfig(ctx context.Context, conf pfconfigdriver.PfStats) error {

	// Read DB config
	configDatabase := readDBConfig()
	connectDB(configDatabase, MySQLdatabase)
	MySQLdatabase.SetMaxIdleConns(0)
	MySQLdatabase.SetMaxOpenConns(500)

	job := func() {}

	switch conf.Type {
	case "mysql_query":
		job = func() {
			rows, err := MySQLdatabase.Query(conf.MySQLQuery)
			if err != nil {
				log.LoggerWContext(ctx).Error(err.Error())
				return
			}
			defer rows.Close()
			var (
				result string
			)
			for rows.Next() {
				err := rows.Scan(&result)
				if err != nil {
					log.LoggerWContext(ctx).Error(err.Error())
					return
				}
				SendMetricConfig(ctx, conf, result)
			}
			return
		}
		break

	default:
		log.LoggerWContext(ctx).Info("Unhandled type: " + conf.Type)
	}

	_, err := interval.Every(conf.Interval).Run(job)
	if err != nil {
		return err
	}

	return nil
}

func SendMetricConfig(ctx context.Context, conf pfconfigdriver.PfStats, metric string) {
	switch conf.StatsdType {
	case "gauge":
		StatsdClient.Gauge(conf.StatsdNS, metric)
		log.LoggerWContext(ctx).Info("Column: " + metric)

	default:
		log.LoggerWContext(ctx).Info("Unhandled statsd type: " + conf.StatsdType)
	}
}
