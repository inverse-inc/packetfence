package clientapi

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/coreos/go-systemd/v22/dbus"
	"github.com/go-chi/chi"
	"github.com/go-chi/chi/middleware"
)

// Handler struct
type API struct {
	Router *chi.Mux
	Ctx    *context.Context
}

type Service struct {
	name string
}

func NewApi() API {
	var Api = API{}
	Api.Router = chi.NewRouter()
	Api.setupRoutes()
	return Api
}

func (api *API) setupRoutes() {
	api.Router.Use(middleware.RequestID)
	api.Router.Use(middleware.RealIP)
	api.Router.Use(middleware.Logger)
	api.Router.Use(middleware.Recoverer)

	api.Router.Route("/api/v1", func(r chi.Router) {
		// CAS api endpoint
		r.Route("/service", func(r chi.Router) {
			r.Get("/status", status(api))
			r.Post("/start", start(api))
			r.Post("/stop", stop(api))
		})
		// CA api endpoint
		r.Route("/logs", func(r chi.Router) {
			r.Get("/collector", collector(api))
			r.Get("/connector", connector(api))
			r.Get("/ntlm-auth", ntlmAuth(api))
		})
		// Profiles api endpoint
		r.Route("/status", func(r chi.Router) {
			r.Get("/", connectorStatus(api))
		})
	})
}

func (api *API) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	// Set the context in the API handler
	*api.Ctx = ctx

	// Serve the request using the chi router
	api.Router.ServeHTTP(w, r)
}

// status handles the status endpoint
func status(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		service := chi.URLParam(req, "service")
		if service == "" {
			http.Error(res, "Service name is required", http.StatusBadRequest)
			return
		}
		// Here you would typically check the status of the service
		err := api.ServiceStatus(service)
		if err != nil {
			http.Error(res, fmt.Sprintf("Failed to get service status: %v", err), http.StatusInternalServerError)
			return
		}
		status := "running" // Placeholder for actual service status check
		res.Header().Set("Content-Type", "application/json")
		res.WriteHeader(http.StatusOK)
		res.Write([]byte(`{"service": "` + service + `", "status": "` + status + `"}`))

	})
}

// start handles the start endpoint
func start(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

	})
}

// stop handles the stop endpoint
func stop(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

	})
}

// collector handles the collector endpoint
func collector(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

	})
}

// connector handles the connector endpoint
func connector(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

	})
}

// ntlmAuth handles the NTLM authentication endpoint
func ntlmAuth(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

	})
}

// connectorStatus handles the connector status endpoint
func connectorStatus(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

	})
}

// Start starts the API server
func (api *API) Start(ctx context.Context, addr string) error {
	server := &http.Server{
		Addr:    addr,
		Handler: api,
	}

	go func() {
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			panic(err)
		}
	}()

	// Wait for the context to be done
	<-ctx.Done()

	// Shutdown the server gracefully
	return server.Shutdown(ctx)
}

func (api *API) ServiceStatus(targetSystemdUnit string) error {

	systemdConnection, err := dbus.NewSystemConnectionContext(*api.Ctx)

	if err != nil {
		fmt.Printf("Failed to connect to systemd: %v\n", err)
		panic(err)
	}
	defer systemdConnection.Close()

	filterUnits := func(unit string) bool {
		return unit != targetSystemdUnit
	}

	// Configure which changes we care about
	isRelevantChangeFunc := func(before *dbus.UnitStatus, after *dbus.UnitStatus) bool {
		if before.ActiveState != after.ActiveState {
			fmt.Printf("Active state changed from %s to %s\n", before.ActiveState, after.ActiveState)
			return true
		}
		if before.SubState != after.SubState {
			fmt.Printf("Sub state changed from %s to %s\n", before.SubState, after.SubState)
			return true
		}
		return false
	}

	// Subscribe to the changes
	channelBuffer := 10

	changeCh, errorCh := systemdConnection.SubscribeUnitsCustom(time.Millisecond*10, channelBuffer, isRelevantChangeFunc, filterUnits)

	// Wait for the service to be active and running or give up
	for {
		select {
		case changedUnits := <-changeCh:
			unitStatus := changedUnits[targetSystemdUnit]
			fmt.Printf("Unit %s has changed\n", targetSystemdUnit)
			fmt.Printf("UnitStatus dump: %+v \n", unitStatus)
			if unitStatus.ActiveState == "active" && unitStatus.SubState == "running" {
				fmt.Printf("Unit %s is now active and running\n", targetSystemdUnit)
				return nil
			}
		case <-errorCh:
			fmt.Printf("Error while waiting for unit %s to change\n", targetSystemdUnit)
			return errors.New("Error while waiting for unit to change")
		case <-time.After(30 * time.Second):
			fmt.Printf("Timed out waiting for restart job to complete for unit: %s\n", targetSystemdUnit)
			return errors.New("Timed out waiting for unit to change")
		}
	}
}
