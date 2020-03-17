package main

import (
	"database/sql"
	"flag"
	"fmt"
	"sync"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/google/uuid"
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
	insertBandwidthAccounting, err := db.Prepare(`insert into bandwidth_accounting VALUES(1, ?, ?, ?, ?, ?, ?)`)
	sharedutils.CheckError(err)

	rowsPerEndpoint := *rows / *endpointsCount

	concurrencyChan := make(chan int, *concurrency)

	wg := sync.WaitGroup{}

	// start at a00000000001
	startMac := 175921860444161
	for i := 0; i < *endpointsCount; i++ {
		mac := sharedutils.CleanMac(fmt.Sprintf("%x", startMac+i))
		for j := 0; j < rowsPerEndpoint; j++ {
			concurrencyChan <- 1
			go func(j int) {
				wg.Add(1)
				defer wg.Done()
				_, err := insertBandwidthAccounting.Exec(mac, uuid.New().String(), startAt.Add(time.Duration(j)*time.Duration(*bucketSize)*time.Second), 1, 1, 2)
				sharedutils.CheckError(err)
				<-concurrencyChan
			}(j)
		}
	}

	wg.Wait()
}
