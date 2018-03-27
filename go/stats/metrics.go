package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"math"
	"net"
	"strconv"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/oliveagle/jsonpath"

	"github.com/inverse-inc/packetfence/go/interval"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	util "github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
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
				switch conf.StatsdType {
				case "count":
					f64Result, _ := strconv.ParseFloat(result, 64)
					StatsdClient.Count(conf.StatsdNS, f64Result)
					break

				case "gauge":
					f64Result, _ := strconv.ParseFloat(result, 64)
					StatsdClient.Gauge(conf.StatsdNS, f64Result)
					break

				case "histogram":
					f64Result, _ := strconv.ParseFloat(result, 64)
					StatsdClient.Histogram(conf.StatsdNS, f64Result)
					break

				case "increment":
					StatsdClient.Increment(conf.StatsdNS)
					break

				case "unique":
					StatsdClient.Unique(conf.StatsdNS, result)
					break

				default:
					log.LoggerWContext(ctx).Warn("Unhandled statsd_type " + conf.StatsdType + " for " + conf.Type)
				}
				break
			}
			return
		}
		break

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
						log.LoggerWContext(ctx).Error(err.Error())
						return
					}
					duration := c.Duration()
					switch conf.StatsdType {
					case "count":
						f64Duration := float64(duration / time.Millisecond)
						StatsdClient.Count(conf.StatsdNS, f64Duration)
						break

					case "gauge":
						f64Duration := float64(duration / time.Millisecond)
						StatsdClient.Gauge(conf.StatsdNS, f64Duration)
						break

					case "histogram":
						f64Duration := float64(duration / time.Millisecond)
						StatsdClient.Histogram(conf.StatsdNS, f64Duration)
						break

					case "timing":
						c.Send(conf.StatsdNS)
						break

					default:
						log.LoggerWContext(ctx).Warn("Unhandled statsd_type " + conf.StatsdType + " for " + conf.Type)
					}
				}
			}
		}
		break

	case "api":
		job = func() {
			var raw json.RawMessage
			apiclient := unifiedapiclient.NewFromConfig(ctx)
			switch conf.ApiMethod {
			case "GET":
				err := apiclient.Call(ctx, "GET", conf.ApiPath, &raw)
				if err != nil {
					log.LoggerWContext(ctx).Error("API error", err.Error())
					return
				}
				break
			case "DELETE", "PATCH", "POST", "PUT":
				err := apiclient.CallWithStringBody(ctx, conf.ApiMethod, conf.ApiPath, conf.ApiPayload, &raw)
				if err != nil {
					log.LoggerWContext(ctx).Error("API error", err.Error())
					return
				}
				break
			default:
				log.LoggerWContext(ctx).Warn("Unhandled api_method " + conf.ApiMethod)
				return
			}

			//temporary workaround for issue: https://github.com/oliveagle/jsonpath/issues/12
			if string(raw[0]) == "[" && string(raw[len(raw)-1]) == "]" {
				//wrap `raw` in {"items": ... }
				raw = []byte("{\"items\":" + string(raw) + "}")
			}

			if raw == nil {
				log.LoggerWContext(ctx).Warn("Empty response from " + conf.ApiMethod + " " + conf.ApiPath)
				return
			}
			var json_data interface{}
			json.Unmarshal([]byte(raw), &json_data)
			res, err := jsonpath.JsonPathLookup(json_data, conf.ApiCompile)
			if err != nil {
				log.LoggerWContext(ctx).Warn("api_compile '"+conf.ApiCompile+"' error from "+conf.ApiMethod+" "+conf.ApiPath, err.Error())
				return
			}
			if res == nil {
				log.LoggerWContext(ctx).Warn("api_compile '" + conf.ApiCompile + "' returns nil from " + conf.ApiMethod + " " + conf.ApiPath)
				return
			}
			switch conf.StatsdType {
			case "count":
				StatsdClient.Count(conf.StatsdNS, res.(float64))
				break

			case "gauge":
				StatsdClient.Gauge(conf.StatsdNS, res.(float64))
				break

			case "histogram":
				StatsdClient.Histogram(conf.StatsdNS, res.(float64))
				break

			case "increment":
				StatsdClient.Increment(conf.StatsdNS)
				break

			case "unique":
				StatsdClient.Unique(conf.StatsdNS, res.(string))
				break

			default:
				log.LoggerWContext(ctx).Warn("Unhandled statsd_type " + conf.StatsdType + " for " + conf.Type)
			}
		}

	default:
		log.LoggerWContext(ctx).Warn("Unhandled type: " + conf.Type)
	}

	_, err := interval.Every(conf.Interval).Randomize().Run(job)
	if err != nil {
		return err
	}

	return nil
}
