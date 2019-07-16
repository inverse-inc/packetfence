package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
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

func ProcessMetricConfig(ctx context.Context, conf pfconfigdriver.PfStats, dorun func() bool) error {

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
			namespace := CleanNameSpace(conf.StatsdNS)
			for rows.Next() {
				switch len(cols) {
				case 1:
					//single column
					err := rows.Scan(&result)
					if err != nil {
						log.LoggerWContext(ctx).Error("Error while reading data from query result: " + err.Error())
						return
					}

				case 2:
					//double column
					err := rows.Scan(&field, &result)
					if err != nil {
						log.LoggerWContext(ctx).Error("Error while reading data from query result: " + err.Error())
						return
					}
					switch field.String {
					case "":
						namespace = CleanNameSpace(conf.StatsdNS + ";NULL")

					default:
						namespace = CleanNameSpace(conf.StatsdNS + "." + field.String)
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

			res, err := CompileJson(json_data, conf.ApiCompile)
			if err != nil {
				log.LoggerWContext(ctx).Warn("Compile error '" + conf.ApiCompile + "' parse error from " + conf.ApiMethod + " " + conf.ApiPath + ": " + err.Error())
			}

			switch res.(type) {
			case []interface{}:
				//single column
				for _, row := range res.([]interface{}) {
					switch conf.StatsdType {
					case "count":
						StatsdClient.Count(conf.StatsdNS, row.(float64))

					case "gauge":
						StatsdClient.Gauge(conf.StatsdNS, row.(float64))

					case "histogram":
						StatsdClient.Histogram(conf.StatsdNS, row.(float64))

					case "increment":
						StatsdClient.Increment(conf.StatsdNS)

					case "unique":
						StatsdClient.Unique(conf.StatsdNS, row.(string))

					default:
						log.LoggerWContext(ctx).Warn("Unhandled statsd_type " + conf.StatsdType + " for " + conf.Type)
					}
				}

			case [][2]interface{}:
				//double column
				var namespace string
				for _, row := range res.([][2]interface{}) {
					namespace = CleanNameSpace(conf.StatsdNS + "." + row[0].(string))
					f64Result, _ := strconv.ParseFloat(row[1].(string), 64)
					switch conf.StatsdType {
					case "count":
						StatsdClient.Count(namespace, f64Result)

					case "gauge":
						StatsdClient.Gauge(namespace, f64Result)

					case "histogram":
						StatsdClient.Histogram(namespace, f64Result)

					case "increment":
						StatsdClient.Increment(namespace)

					case "unique":
						StatsdClient.Unique(namespace, row[1].(string))

					default:
						log.LoggerWContext(ctx).Warn("Unhandled statsd_type " + conf.StatsdType + " for " + conf.Type)
					}

				}

			default:
				log.LoggerWContext(ctx).Warn("Unhandled response type from " + conf.ApiMethod + " " + conf.ApiPath)
			}
		}

	default:
		log.LoggerWContext(ctx).Warn("Unhandled type: " + conf.Type)
	}

	switch strings.ToLower(conf.Randomize) {
	case "1", "t", "true", "y", "yes":
		_, err := interval.Every(conf.Interval).Randomize().DoRun(dorun).Run(job)
		if err != nil {
			return err
		}

	default:
		_, err := interval.Every(conf.Interval).DoRun(dorun).Run(job)
		if err != nil {
			return err
		}
	}

	return nil
}

/*
 * Compiles JSON Xpath and returns a slice of either:
 *     a slice of one-to-many value(s) - if Xpath is singular
 *     a slice of one-to-many double value(s) - if Xpath is plural
 *
 * `json` is the JSON body
 *
 * `compile` is the Xpath string
 *     Examples: http://goessner.net/articles/JsonPath/
 *
 *     Can be either:
 *         a single Xpath (eg: $.items[0].somevalue)
 *         or 2x Xpaths separated with a comma (eg: $.items[0].somekey, $.item[0].somevalue)
 */
func CompileJson(json interface{}, compile string) (interface{}, error) {
	c := strings.Split(compile, ",")
	if len(c) > 1 {
		// multiple XPath(s)
		r1, err := CompileJson(json, c[0])
		if err != nil {
			return nil, err
		}

		r2, err := CompileJson(json, c[1])
		if err != nil {
			return nil, err
		}

		zipped, err := Zip(r1.([]interface{}), r2.([]interface{}))
		if err != nil {
			return nil, err
		}

		return zipped, nil
	}
	//single Xpath
	compile = strings.Trim(compile, " ")
	p, err := jsonpath.Parse(compile)
	if err != nil {
		return nil, err
	}

	res, err := p.Apply(json)
	if err != nil {
		return nil, err
	}

	switch res.(type) {
	case string, float64, bool, nil:
		return []interface{}{res}, nil

		/*
		 * Xpath parser may return nested slices (eg: [[1], [2, 3] [4, 5, 6]]),
		 *     thus we check the type and glue them back together (eg: [1, 2, 3, 4, 5, 6])
		 */
	case []interface{}:
		var ret []interface{}
		for _, r := range res.([]interface{}) {
			switch r.(type) {
			case float64:
				ret = append(ret, strconv.FormatFloat(r.(float64), 'f', 2, 64))

			case string, bool, nil:
				ret = append(ret, r)

			case []interface{}:
				for _, _r := range r.([]interface{}) {
					ret = append(ret, _r)
				}

			default:
				return nil, errors.New("Unhandled response type")

			}
		}
		return ret, nil

	default:
		return nil, errors.New("Unhandled response type")
	}
}

/*
 * Glues 2 []interface{} together into a single slice with 2 elements,
 *     example: Zip([santa tooth], [clause, fairy]) = [[santa clause] [tooth fairy]]
 * Used to match name(s) with value(s) from 2 separate JSON Xpaths
 */
func Zip(a, b []interface{}) ([][2]interface{}, error) {
	if len(a) != len(b) {
		return nil, errors.New("Zip arguments must be of same length")
	}
	r := make([][2]interface{}, len(a), len(a))
	for i, e := range a {
		r[i] = [2]interface{}{e, b[i]}
	}

	return r, nil
}

func CleanNameSpace(namespace string) string {
	// ":" is a reserved statsd separator between namespace and metric
	return strings.Replace(namespace, ":", "_", -1)
}
