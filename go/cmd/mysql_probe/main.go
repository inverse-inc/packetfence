package main

import (
	"context"
	"net/http"
	"time"

	"github.com/coreos/go-systemd/daemon"
	"github.com/gorilla/mux"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/galeraautofix/mariadb"
)

var ctx = context.Background()

func main() {

	router := mux.NewRouter()
	router.HandleFunc("/", checkDB).Methods("OPTIONS")

	srv := &http.Server{
		Addr:        ":3307",
		IdleTimeout: 5 * time.Second,
		Handler:     router,
	}
	// Systemd
	daemon.SdNotify(false, "READY=1")

	go func() {
		interval, err := daemon.SdWatchdogEnabled(false)
		if err != nil || interval == 0 {
			return
		}
		cli := &http.Client{}
		for {
			req, err := http.NewRequest("GET", "http://127.0.0.1:3307", nil)
			if err != nil {
				log.LoggerWContext(ctx).Error(err.Error())
				continue
			}
			req.Close = true
			resp, err := cli.Do(req)
			time.Sleep(100 * time.Millisecond)
			if err != nil {
				log.LoggerWContext(ctx).Error(err.Error())
				continue
			}
			resp.Body.Close()

			if err == nil {
				daemon.SdNotify(false, "WATCHDOG=1")
			}
			time.Sleep(interval / 3)
		}
	}()
	srv.ListenAndServe()
}

func checkDB(res http.ResponseWriter, req *http.Request) {

	Available := mariadb.IsLocalDBAvailable(ctx)

	if Available {
		Available = mariadb.IsLocalDBReady(ctx)
		if Available {
			res.WriteHeader(http.StatusOK)
		} else {
			res.WriteHeader(http.StatusServiceUnavailable)
		}

	} else {
		res.WriteHeader(http.StatusServiceUnavailable)
	}

}
