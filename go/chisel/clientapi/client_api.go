package clientapi

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"time"

	"github.com/go-chi/chi"
	"github.com/go-chi/chi/middleware"
	systemdmanager "github.com/inverse-inc/packetfence/go/systemdmanager"
)

// Handler struct
type API struct {
	Router          *chi.Mux
	TerminalEnabled bool
	ConnectorId     string
	commandChan     chan Message
	ctx             context.Context
	cancel          context.CancelFunc
	serverRunning   int32
}

type MessageType int

const (
	StartProcessing MessageType = iota
	StopProcessing
	EmergencyShutdown
)

// Message contient le type et des données optionnelles
type Message struct {
	Type MessageType
}

type Service struct {
	Name string `json:"service"`
}

func NewApi(ctx context.Context, ConnectorID string) API {
	var Api = API{}
	Api.Router = chi.NewRouter()
	Api.ctx = ctx
	Api.ConnectorId = strings.Split(ConnectorID, ":")[0]
	var err error
	Api.commandChan = make(chan Message)
	if err != nil {
		log.Printf("Error initializing terminal: %v", err)
	}
	Api.TerminalEnabled, err = Api.terminal()

	Api.setupRoutes()

	return Api
}

func (api *API) setupRoutes() {
	api.Router.Use(middleware.RequestID)
	api.Router.Use(middleware.RealIP)
	api.Router.Use(middleware.Logger)
	api.Router.Use(middleware.Recoverer)

	api.Router.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Origin, Content-Type, Accept, Authorization, Upgrade, Connection, Sec-WebSocket-Key, Sec-WebSocket-Version, Sec-WebSocket-Protocol")

			if r.Method == "OPTIONS" {
				w.WriteHeader(http.StatusOK)
				return
			}

			next.ServeHTTP(w, r)
		})
	})

	// Configure GoTTY reverse proxy
	gottyURL, err := url.Parse("http://localhost:8022")
	if err != nil {
		log.Fatal("Error parsing URL GoTTY:", err)
	}

	proxy := httputil.NewSingleHostReverseProxy(gottyURL)

	originalDirector := proxy.Director
	proxy.Director = func(req *http.Request) {
		originalDirector(req)
		req.Host = gottyURL.Host

		if strings.ToLower(req.Header.Get("Upgrade")) == "websocket" {
			req.Header.Set("X-Forwarded-Proto", "http")
			req.Header.Set("X-Forwarded-Host", req.Host)
			req.Header.Set("Origin", "http://"+gottyURL.Host)
		}
	}

	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.Printf("Erreur proxy: %v", err)
		w.Header().Set("Content-Type", "text/html")
		w.WriteHeader(http.StatusBadGateway)
		w.Write([]byte(`
<!DOCTYPE html>
<html>
<head>
    <title>Service Unavailable</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 100px; }
        .error { color: #e74c3c; }
    </style>
</head>
<body>
    <h1 class="error">⚠️ Service Terminal Unavailable</h1>
    <p>The terminal is temporarily unavailable. Please try again in a few moments.</p>
    <p><a href="/">← Back to home</a></p>
</body>
</html>
		`))
	}

	api.Router.Route("/api/v1", func(r chi.Router) {
		r.Group(func(r chi.Router) {
			r.Use(localhostOnly)
			r.HandleFunc("/terminal/*", func(w http.ResponseWriter, r *http.Request) {
				r.URL.Path = strings.TrimPrefix(r.URL.Path, "/api/v1/terminal")
				if r.URL.Path == "" {
					r.URL.Path = "/"
				}
				proxy.ServeHTTP(w, r)
			})

			r.HandleFunc("/terminal", func(w http.ResponseWriter, r *http.Request) {
				http.Redirect(w, r, "/api/v1/terminal/", http.StatusMovedPermanently)
			})

			r.Route("/service", func(r chi.Router) {
				r.Post("/all", statusAll(api))
				r.Post("/status", status(api))
				r.Post("/start", manageService(api, "start"))
				r.Post("/stop", manageService(api, "stop"))
				r.Post("/restart", manageService(api, "restart"))
			})
			r.Handle("/logs", handleWebSocketConnection())
			r.Route("/status", func(r chi.Router) {
				r.Get("/", connectorStatus(api))
			})
		})
		r.Get("/authorize/{id}", enableTerminal(api))
	})
}

func localhostOnly(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Extraire l'IP de la requête
		ip := r.RemoteAddr
		if host, _, err := net.SplitHostPort(ip); err == nil {
			ip = host
		}

		// Vérifier si c'est localhost
		if ip != "127.0.0.1" && ip != "::1" {
			http.Error(w, "Access denied", http.StatusForbidden)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func (api *API) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Serve the request using the chi router
	api.Router.ServeHTTP(w, r)
}

func enableTerminal(api *API) http.HandlerFunc {

	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		id := chi.URLParam(req, "id")
		if id == "" {
			http.Error(res, "Missing terminal ID", http.StatusBadRequest)
			return
		}

		r, err := http.Get(fmt.Sprintf("http://127.0.0.1:22226/api/v1/pfconnector/remote-terminal?connectorid=%s&id=%s", api.ConnectorId, id))

		if err != nil {
			http.Error(res, fmt.Sprintf("Failed to enable terminal: %v", err), http.StatusInternalServerError)
			return
		}
		defer r.Body.Close()
		if r.StatusCode != http.StatusOK {
			http.Error(res, fmt.Sprintf("Failed to enable terminal: %s", r.Status), http.StatusInternalServerError)
			return
		}
		var j map[string]interface{}
		json.NewDecoder(r.Body).Decode(&j)
		if j["authorized"] == false {
			http.Error(res, "Terminal not authorized", http.StatusForbidden)
			return
		}
		if j["authorized"] == nil || j["authorized"] != true {
			http.Error(res, "Terminal not authorized", http.StatusForbidden)
			return
		}

		select {
		case api.commandChan <- Message{Type: StartProcessing}:
			log.Println("Start command sent successfully")
		case <-time.After(time.Second * 5):
			http.Error(res, "Timeout sending start command", http.StatusForbidden)
			return
		}

		res.Header().Set("Content-Type", "application/json")
		res.WriteHeader(http.StatusOK)
		res.Write([]byte(`{"message": "Terminal is enabled"}`))
	})
}

// status handles the status endpoint
func status(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var srv Service
		if err := json.NewDecoder(req.Body).Decode(&srv); err != nil {
			http.Error(res, err.Error(), http.StatusBadRequest)
			return
		}

		if srv.Name == "" {
			http.Error(res, "Service name is required (packetfence-fingerbank-collector.service, packetfence-ntlm-auth-api-remote.service, packetfence-ntlm-join-remote.service, packetfence-pfconnector-remote.service)", http.StatusBadRequest)
			return
		}

		systemd, err := systemdmanager.NewSystemdManager()

		if err != nil {
			http.Error(res, fmt.Sprintf("Failed to create systemd manager: %v", err), http.StatusInternalServerError)
			return
		}
		defer systemd.Close()
		allowed := []string{"packetfence-fingerbank-collector.service", "packetfence-ntlm-auth-api-remote.service", "packetfence-ntlm-join-remote.service", "packetfence-pfconnector-remote.service"}
		for _, service := range allowed {
			if srv.Name == service {
				status, substatus, err := systemd.Status(service)
				if err != nil {
					http.Error(res, fmt.Sprintf("Failed to get service status: %v", err), http.StatusNotFound)
					return
				}
				res.Header().Set("Content-Type", "application/json")
				res.WriteHeader(http.StatusOK)
				res.Write([]byte(`{"service": "` + srv.Name + `", "status": "` + status + `" "substatus": "` + substatus + `"}`))
				return

			}
		}
	})
}

func statusAll(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		systemd, err := systemdmanager.NewSystemdManager()

		if err != nil {
			http.Error(res, fmt.Sprintf("Failed to create systemd manager: %v", err), http.StatusInternalServerError)
			return
		}
		defer systemd.Close()

		services, err := systemd.ListSystemdServices()

		if err != nil {
			http.Error(res, fmt.Sprintf("Failed to list services: %v", err), http.StatusInternalServerError)
			return
		}
		res.Header().Set("Content-Type", "application/json")
		res.WriteHeader(http.StatusOK)
		response := make([]map[string]string, len(services))
		for i, service := range services {
			response[i] = map[string]string{
				"name":         service.Name,
				"description":  service.Description,
				"load_state":   service.LoadState,
				"active_state": service.ActiveState,
				"sub_state":    service.SubState,
			}
		}
		jsonResponse, err := json.Marshal(response)
		if err != nil {
			http.Error(res, fmt.Sprintf("Failed to marshal response: %v", err), http.StatusInternalServerError)
			return
		}
		res.Write(jsonResponse)
	})
}

// start handles the start endpoint
func manageService(api *API, action string) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		var srv Service
		if err := json.NewDecoder(req.Body).Decode(&srv); err != nil {
			http.Error(res, err.Error(), http.StatusBadRequest)
			return
		}

		if srv.Name == "" {
			http.Error(res, "Service name is required (packetfence-fingerbank-collector.service, packetfence-ntlm-auth-api-remote.service, packetfence-ntlm-join-remote.service, packetfence-pfconnector-remote.service)", http.StatusBadRequest)
			return
		}

		systemd, err := systemdmanager.NewSystemdManager()

		if err != nil {
			http.Error(res, fmt.Sprintf("Failed to create systemd manager: %v", err), http.StatusInternalServerError)
			return
		}
		defer systemd.Close()
		allowed := []string{"packetfence-fingerbank-collector.service", "packetfence-ntlm-auth-api-remote.service", "packetfence-ntlm-join-remote.service", "packetfence-pfconnector-remote.service"}
		for _, service := range allowed {
			if srv.Name == service {

				switch action {
				case "start":
					if err := systemd.Start(srv.Name); err != nil {
						http.Error(res, fmt.Sprintf("Failed to start service %s: %v", srv.Name, err), http.StatusInternalServerError)
						return
					}
					res.WriteHeader(http.StatusOK)
					res.Write([]byte(fmt.Sprintf("Service %s started successfully", srv.Name)))
					return
				case "stop":
					if err := systemd.Stop(srv.Name); err != nil {
						http.Error(res, fmt.Sprintf("Failed to stop service %s: %v", srv.Name, err), http.StatusInternalServerError)
						return
					}
					res.WriteHeader(http.StatusOK)
					res.Write([]byte(fmt.Sprintf("Service %s stopped successfully", srv.Name)))
					return
				case "restart":
					if err := systemd.Restart(srv.Name); err != nil {
						http.Error(res, fmt.Sprintf("Failed to restart service %s: %v", srv.Name, err), http.StatusInternalServerError)
						return
					}
					res.WriteHeader(http.StatusOK)
					res.Write([]byte(fmt.Sprintf("Service %s restarted successfully", srv.Name)))
					return
				default:
					http.Error(res, "Invalid action specified", http.StatusBadRequest)
					return

				}
			}
		}
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
