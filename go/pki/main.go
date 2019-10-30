package main

import (
	"context"
	"net/http"
	"time"

	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/jinzhu/gorm"
)

// Handler struct
type Handler struct {
	database *gorm.DB
	router   *mux.Router
}

var ctx = context.Background()

// Database global var
var Database *gorm.DB

func main() {
	log.SetProcessName("pfpki")
	ctx = log.LoggerNewContext(ctx)
	pfpki := Handler{}

	Database, _ = gorm.Open("mysql", db.ReturnURI)
	defer Database.Close()

	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	pfpki.database = Database

	pfpki.router = mux.NewRouter()
	api := pfpki.router.PathPrefix("/api/v1").Subrouter()
	api.HandleFunc("/pki/newca", newCA).Methods("POST")
	api.HandleFunc("/pki/newprofile", newProfile).Methods("POST")
	api.HandleFunc("/pki/newcert", newCert).Methods("POST")

	srv := &http.Server{
		Addr:        "127.0.0.1:12345",
		IdleTimeout: 5 * time.Second,
		Handler:     pfpki.router,
	}
	srv.ListenAndServe()

}
