package main

import (
	"context"
	"database/sql"
	"net/http"
	"time"

	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

// Handler struct
type Handler struct {
	database *sql.DB
	router   *mux.Router
}

var ctx = context.Background()

func main() {
	log.SetProcessName("pfpki")
	ctx = log.LoggerNewContext(ctx)
	pfpki := Handler{}

	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	db, err := db.DbFromConfig(ctx)
	sharedutils.CheckError(err)
	pfpki.database = db

	pfpki.router = mux.NewRouter()
	api := pfpki.router.PathPrefix("/api/v1").Subrouter()
	api.HandleFunc("/pki/new_ca", newCA).Methods("POST")

	srv := &http.Server{
		Addr:        "127.0.0.1:12345",
		IdleTimeout: 5 * time.Second,
		Handler:     pfpki.router,
	}
	srv.ListenAndServe()

}
