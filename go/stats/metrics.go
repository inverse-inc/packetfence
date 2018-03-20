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
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Database)
	configDatabase := pfconfigdriver.Config.PfConf.Database
	connectDB(configDatabase)

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
	log.LoggerWContext(ctx).Info("Metric " + conf.StatsdNS + ": " + metric)
	switch conf.StatsdType {
	case "count":
		StatsdClient.Count(conf.StatsdNS, metric)
		break

	case "gauge":
		StatsdClient.Gauge(conf.StatsdNS, metric)
		break

	case "histogram":
		StatsdClient.Histogram(conf.StatsdNS, metric)
		break

	case "unique":
		StatsdClient.Unique(conf.StatsdNS, metric)
		break

	default:
		log.LoggerWContext(ctx).Info("Unhandled statsd type: " + conf.StatsdType)
	}
}
