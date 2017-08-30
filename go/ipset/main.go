package main

import (
	"context"
	"log"
	"net"
	"net/http"
	"time"

	"github.com/coreos/go-systemd/daemon"
	"github.com/gorilla/mux"
)

var ctx = context.Background()

func main() {
	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	router := mux.NewRouter()
	router.HandleFunc("/ipsetmarklayer3/{network:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{type:[a-zA-Z]+}/{catid:[0-9]+}/{ip:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{local:[0-1]}", handleLayer3).Methods("POST")
	router.HandleFunc("/ipsetmarklayer2/{network:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{type:[a-zA-Z]+}/{catid:[0-9]+}/{ip:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}/{local:[0-1]}", handleLayer2).Methods("POST")
	router.HandleFunc("/ipsetunmarkmac/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}/{local:[0-1]}", handleUnmarkMac).Methods("POST")
	router.HandleFunc("/ipsetunmarkip/{ip:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{local:[0-1]}", handleUnmarkIp).Methods("POST")
	router.HandleFunc("/ipsetmarkiplayer2/{network:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{catid:[0-9]+}/{ip:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{local:[0-1]}", handleMarkIpL2).Methods("POST")
	router.HandleFunc("/ipsetmarkiplayer3/{network:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{catid:[0-9]+}/{ip:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}/{local:[0-1]}", handleMarkIpL3).Methods("POST")

	// Api
	l, err := net.Listen("tcp", ":22223")
	if err != nil {
		log.Panicf("cannot listen: %s", err)
	}

	// detectMembers()
	daemon.SdNotify(false, "READY=1")

	go func() {
		interval, err := daemon.SdWatchdogEnabled(false)
		if err != nil || interval == 0 {
			return
		}
		for {
			_, err := http.Get("http://127.0.0.1:22223")
			if err == nil {
				daemon.SdNotify(false, "WATCHDOG=1")
			}
			time.Sleep(interval / 3)
		}
	}()
	http.Serve(l, router)

}
