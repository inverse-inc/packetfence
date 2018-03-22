package main

import (
	"context"
	"database/sql"
	"strconv"

	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/packetfence/go/interval"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

var MySQLdatabase *sql.DB

func ProcessMetricConfig(ctx context.Context, conf pfconfigdriver.PfStats) error {

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
				break
			}
			return
		}
		break

	default:
		log.LoggerWContext(ctx).Warn("Unhandled type: " + conf.Type)
	}

	_, err := interval.Every(conf.Interval).Randomize().Run(job)
	if err != nil {
		return err
	}

	return nil
}

func SendMetricConfig(ctx context.Context, conf pfconfigdriver.PfStats, metric string) {
	switch conf.StatsdType {
	case "count":
		f, _ := strconv.ParseFloat(metric, 64)
		StatsdClient.Count(conf.StatsdNS, f)
		break

	case "gauge":
		f, _ := strconv.ParseFloat(metric, 64)
		StatsdClient.Gauge(conf.StatsdNS, f)
		break

	case "histogram":
		f, _ := strconv.ParseFloat(metric, 64)
		StatsdClient.Histogram(conf.StatsdNS, f)
		break

	case "unique":
		StatsdClient.Unique(conf.StatsdNS, metric)
		break

	default:
		log.LoggerWContext(ctx).Warn("Unhandled statsd type: " + conf.StatsdType)
	}
}
