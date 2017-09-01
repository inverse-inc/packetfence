package main

import (
	"context"
	"crypto/tls"
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
	cfg := &tls.Config{
		MinVersion:               tls.VersionTLS12,
		CurvePreferences:         []tls.CurveID{tls.CurveP521, tls.CurveP384, tls.CurveP256},
		PreferServerCipherSuites: true,
		CipherSuites: []uint16{
			tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
			tls.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,
			tls.TLS_RSA_WITH_AES_256_GCM_SHA384,
			tls.TLS_RSA_WITH_AES_256_CBC_SHA,
		},
	}
	srv := &http.Server{
		Addr:         ":22223",
		Handler:      router,
		TLSConfig:    cfg,
		TLSNextProto: make(map[string]func(*http.Server, *tls.Conn, http.Handler), 0),
	}

	// detectMembers()
	daemon.SdNotify(false, "READY=1")

	go func() {
		interval, err := daemon.SdWatchdogEnabled(false)
		if err != nil || interval == 0 {
			return
		}
		for {
			_, err := http.Get("https://127.0.0.1:22223")
			if err == nil {
				daemon.SdNotify(false, "WATCHDOG=1")
			}
			time.Sleep(interval / 3)
		}
	}()
	srv.ListenAndServeTLS("tls.crt", "tls.key")

}
