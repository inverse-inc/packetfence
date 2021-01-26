package main

import (
	"database/sql"
	"flag"
	"fmt"
	"math/rand"
	"sync"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/packetfence/go/mac"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

var rows = flag.Int("rows", 10000, "The amount of rows to insert")
var endpointsCount = flag.Int("endpoints", 1000, "The amount of endpoints to use")
var startDate = flag.String("start-date", "", "The date the buckets should start")
var bucketSize = flag.Int("bucket-size", 300, "The bucket size in seconds")

var dbProto = flag.String("db-proto", "tcp", "The DB proto")
var dbHost = flag.String("db-host", "localhost", "The DB host")
var dbUser = flag.String("db-user", "pf", "The DB user")
var dbPass = flag.String("db-pass", "pf", "The DB pass")
var dbName = flag.String("db-name", "pf", "The DB name")

var concurrency = flag.Int("concurrency", 5, "The amount of concurrency to do")

func connectDB() *sql.DB {
	uri := fmt.Sprintf("%s:%s@%s(%s)/%s?parseTime=true&loc=Local", *dbUser, *dbPass, *dbProto, *dbHost, *dbName)
	db, err := sql.Open("mysql", uri)
	sharedutils.CheckError(err)
	db.SetMaxIdleConns(5)
	db.SetMaxOpenConns(100)
	db.SetConnMaxLifetime(time.Minute * 5)
	return db
}

func main() {
	flag.Parse()

	var startAt time.Time
	if *startDate != "" {
		var err error
		startAt, err = time.ParseInLocation("2006-01-02 15:04:05", *startDate, time.Local)
		sharedutils.CheckError(err)
	} else {
		startAt = time.Now()
	}

	db := connectDB()
	/*
	   node_id BIGINT UNSIGNED NOT NULL,
	   unique_session_id BIGINT UNSIGNED NOT NULL,
	   time_bucket DATETIME NOT NULL,
	   in_bytes BIGINT SIGNED NOT NULL,
	   out_bytes BIGINT SIGNED NOT NULL,
	   mac CHAR(17) NOT NULL,
	   tenant_id SMALLINT NOT NULL,
	*/
	insertBandwidthAccounting, err := db.Prepare(`insert into bandwidth_accounting (node_id, unique_session_id, time_bucket, in_bytes, out_bytes, mac, tenant_id, source_type) VALUES(?, ?, ?, ?, ?, ?, 1, "radius")`)
	sharedutils.CheckError(err)

	rowsPerEndpoint := *rows / *endpointsCount

	concurrencyChan := make(chan int, *concurrency)

	wg := sync.WaitGroup{}
	// start at a00000000001
	startMac := 175921860444161
	for i := 0; i < *endpointsCount; i++ {
		mac, _ := mac.NewFromString(fmt.Sprintf("%x", startMac+i))
		for j := 0; j < rowsPerEndpoint; j++ {
			concurrencyChan <- 1
			go func(j int) {
				wg.Add(1)
				defer wg.Done()
				_, err := insertBandwidthAccounting.Exec(mac.NodeId(1), rand.Uint64(), startAt.Add(time.Duration(j)*time.Duration(*bucketSize)*time.Second), 1, 1, mac.String())
				sharedutils.CheckError(err)
				<-concurrencyChan
			}(j)
		}
	}

	wg.Wait()
}
