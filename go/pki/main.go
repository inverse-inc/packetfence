package main

import (
	"context"
	"net/http"
	"time"

	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/jinzhu/gorm"
)

// Handler struct
type Handler struct {
	database *gorm.DB
	router   *mux.Router
}

var ctx = context.Background()

func main() {
	log.SetProcessName("pfpki")
	ctx = log.LoggerNewContext(ctx)
	pfpki := Handler{}

	db, err := gorm.Open("mysql", db.ReturnURI)
	defer db.Close()

	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

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
