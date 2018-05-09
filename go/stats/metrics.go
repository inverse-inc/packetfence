package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"math"
	"net"
	"strconv"
	"strings"
	"time"

	"github.com/gdey/jsonpath"
	_ "github.com/go-sql-driver/mysql"

	"github.com/inverse-inc/packetfence/go/interval"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	util "github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

var MySQLdatabase *sql.DB
var apiClient = unifiedapiclient.NewFromConfig(ctx)

func ProcessMetricConfig(ctx context.Context, conf pfconfigdriver.PfStats) error {

	job := func() {}

	switch conf.Type {
	case "mysql_query":
		job = func() {
			rows, err := MySQLdatabase.Query(conf.MySQLQuery)
			if err != nil {
				log.LoggerWContext(ctx).Error("Error while performing SQL query: " + err.Error())
				return
			}
			defer rows.Close()
			cols, err := rows.Columns()
			if err != nil {
				log.LoggerWContext(ctx).Error("Error while reading columns from query result: " + err.Error())
				return
			}
			var (
				field  sql.NullString
				result string
			)
			namespace := conf.StatsdNS
			for rows.Next() {
				switch len(cols) {
				case 1:
					err := rows.Scan(&result)
					if err != nil {
						log.LoggerWContext(ctx).Error("Error while reading data from query result: " + err.Error())
						return
					}

				case 2:
					err := rows.Scan(&field, &result)
					if err != nil {
						log.LoggerWContext(ctx).Error("Error while reading data from query result: " + err.Error())
						return
					}
					switch field.String {
					case "":
						namespace = conf.StatsdNS + ";NULL"

					default:
						namespace = conf.StatsdNS + ";" + field.String
					}

				default:
					return
				}
				switch conf.StatsdType {
				case "count":
					f64Result, _ := strconv.ParseFloat(result, 64)
					StatsdClient.Count(namespace, f64Result)

				case "gauge":
					f64Result, _ := strconv.ParseFloat(result, 64)
					StatsdClient.Gauge(namespace, f64Result)

				case "histogram":
					f64Result, _ := strconv.ParseFloat(result, 64)
					StatsdClient.Histogram(namespace, f64Result)

				case "increment":
					StatsdClient.Increment(namespace)

				case "unique":
					StatsdClient.Unique(namespace, result)

				default:
					log.LoggerWContext(ctx).Warn("Unhandled statsd_type " + conf.StatsdType + " for " + conf.Type)
				}
			}
			return
		}

	case "icmp_ipv4":
		job = func() {
			t, err := time.ParseDuration(conf.Interval)
			if err != nil {
				log.LoggerWContext(ctx).Warn("Could not parse duration: " + conf.Interval)
				return
			}
			//set timeout one unit less than our interval
			timeout := int(math.Floor(float64(t.Nanoseconds()) * .0000000009))
			//resolv conf.Host to ipv4 address
			addrs, _ := net.LookupIP(conf.Host)
			for _, addr := range addrs {
				if ipv4 := addr.To4(); ipv4 != nil {
					c := StatsdClient.NewTiming()
					err = util.Pinger(ipv4.String(), timeout)
					if err != nil {
						log.LoggerWContext(ctx).Error("Error while pinging address: " + err.Error())
						return
					}
					duration := c.Duration()
					switch conf.StatsdType {
					case "count":
						f64Duration := float64(duration / time.Millisecond)
						StatsdClient.Count(conf.StatsdNS, f64Duration)

					case "gauge":
						f64Duration := float64(duration / time.Millisecond)
						StatsdClient.Gauge(conf.StatsdNS, f64Duration)

					case "histogram":
						f64Duration := float64(duration / time.Millisecond)
						StatsdClient.Histogram(conf.StatsdNS, f64Duration)

					case "timing":
						c.Send(conf.StatsdNS)

					default:
						log.LoggerWContext(ctx).Warn("Unhandled statsd_type " + conf.StatsdType + " for " + conf.Type)
					}
				}
			}
		}

	case "api":
		job = func() {
			var raw json.RawMessage
			switch conf.ApiMethod {
			case "GET":
				err := apiClient.Call(ctx, "GET", conf.ApiPath, &raw)
				if err != nil {
					log.LoggerWContext(ctx).Error("API error: " + err.Error())
					return
				}

			case "DELETE", "PATCH", "POST", "PUT":
				err := apiClient.CallWithStringBody(ctx, conf.ApiMethod, conf.ApiPath, conf.ApiPayload, &raw)
				if err != nil {
					log.LoggerWContext(ctx).Error("API error: " + err.Error())
					return
				}

			default:
				log.LoggerWContext(ctx).Warn("Unhandled api_method " + conf.ApiMethod)
				return
			}

			if raw == nil {
				log.LoggerWContext(ctx).Warn("Empty response from " + conf.ApiMethod + " " + conf.ApiPath)
				return
			}
			var json_data interface{}
			json.Unmarshal([]byte(raw), &json_data)
			prs, err := jsonpath.Parse(conf.ApiCompile)
			if err != nil {
				log.LoggerWContext(ctx).Warn("api_compile '" + conf.ApiCompile + "' parse error from " + conf.ApiMethod + " " + conf.ApiPath + ": " + err.Error())
				return
			}
			res, err := prs.Apply(json_data)
			if err != nil {
				log.LoggerWContext(ctx).Warn("api_compile '" + conf.ApiCompile + "' apply error from " + conf.ApiMethod + " " + conf.ApiPath + ": " + err.Error())
				return
			}
			if res == nil {
				log.LoggerWContext(ctx).Warn("api_compile '" + conf.ApiCompile + "' returns nil from " + conf.ApiMethod + " " + conf.ApiPath)
				return
			}
			switch conf.StatsdType {
			case "count":
				StatsdClient.Count(conf.StatsdNS, res.(float64))

			case "gauge":
				StatsdClient.Gauge(conf.StatsdNS, res.(float64))

			case "histogram":
				StatsdClient.Histogram(conf.StatsdNS, res.(float64))

			case "increment":
				StatsdClient.Increment(conf.StatsdNS)

			case "unique":
				StatsdClient.Unique(conf.StatsdNS, res.(string))

			default:
				log.LoggerWContext(ctx).Warn("Unhandled statsd_type " + conf.StatsdType + " for " + conf.Type)
			}
		}

	default:
		log.LoggerWContext(ctx).Warn("Unhandled type: " + conf.Type)
	}

	switch strings.ToLower(conf.Randomize) {
	case "1", "t", "true", "y", "yes":
		_, err := interval.Every(conf.Interval).Randomize().Run(job)
		if err != nil {
			return err
		}

	default:
		_, err := interval.Every(conf.Interval).Run(job)
		if err != nil {
			return err
		}
	}

	return nil
}
