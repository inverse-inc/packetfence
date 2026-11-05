// A complete admin UI plugin service in Go: the scaffold of
// docs/ui-plugins/SCAFFOLDING.md.
//
// It serves its manifest (manifest.json, embedded) and the API of its page, a
// collection of notes kept in memory, then registers itself with the
// PacketFence Go accessors and deregisters itself on SIGTERM or SIGINT.
//
//	go build -o notes-go .
//	./notes-go -listen 127.0.0.1:8092                     # on the host of api-frontend
//	./notes-go -listen :8443 -host notes.example -port 8443 -tls-cert notes.crt -tls-key notes.key
package main

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"flag"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/inverse-inc/packetfence/go/uiplugins"
)

//go:embed manifest.json
var manifest []byte

type note struct {
	ID   string `json:"id"`
	Text string `json:"text"`
}

// the data of the plugin: a real plugin keeps it in its own storage
var (
	lock  sync.Mutex
	notes = map[string]note{"welcome": {ID: "welcome", Text: "Hello from the Go plugin"}}
)

// answer writes a JSON answer: PacketFence passes only JSON to the admin
func answer(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(body)
}

func message(w http.ResponseWriter, status int, text string) {
	answer(w, status, map[string]any{"message": text, "status": status})
}

// the admin PacketFence checked: never the admin token
type admin struct {
	Username string
	Actions  map[string]bool
}

func adminOf(r *http.Request) admin {
	a := admin{Username: r.Header.Get("X-PacketFence-Username"), Actions: map[string]bool{}}
	for _, action := range strings.Split(r.Header.Get("X-PacketFence-Admin-Actions"), ",") {
		a.Actions[action] = true
	}
	return a
}

func sorted() []note {
	list := make([]note, 0, len(notes))
	for _, n := range notes {
		list = append(list, n)
	}
	sort.Slice(list, func(i, j int) bool { return list[i].ID < list[j].ID })
	return list
}

// the page of a list or a search, in the format of the PacketFence API
func page(list []note, cursor, limit int) map[string]any {
	if cursor > len(list) {
		cursor = len(list)
	}
	end := cursor + limit
	if end > len(list) {
		end = len(list)
	}
	body := map[string]any{"items": list[cursor:end], "prevCursor": cursor, "total_count": len(list), "status": 200}
	if end < len(list) {
		body["nextCursor"] = end
	}
	return body
}

func routes() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /manifest.json", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write(manifest)
	})
	// listOptions, itemOptions: the meta of the form fields (none here)
	options := func(w http.ResponseWriter, r *http.Request) { answer(w, 200, map[string]any{"meta": map[string]any{}}) }
	mux.HandleFunc("OPTIONS /notes", options)
	mux.HandleFunc("OPTIONS /notes/{id}", options)
	// list
	mux.HandleFunc("GET /notes", func(w http.ResponseWriter, r *http.Request) {
		cursor, _ := strconv.Atoi(r.URL.Query().Get("cursor"))
		limit, err := strconv.Atoi(r.URL.Query().Get("limit"))
		if err != nil || limit <= 0 {
			limit = 25
		}
		lock.Lock()
		defer lock.Unlock()
		answer(w, 200, page(sorted(), cursor, limit))
	})
	// search: the query of the UI, here a substring of any value
	mux.HandleFunc("POST /notes/search", func(w http.ResponseWriter, r *http.Request) {
		var query struct {
			Query  json.RawMessage `json:"query"`
			Cursor int             `json:"cursor"`
			Limit  int             `json:"limit"`
		}
		json.NewDecoder(r.Body).Decode(&query)
		if query.Limit <= 0 {
			query.Limit = 25
		}
		values := searchValues(query.Query)
		lock.Lock()
		defer lock.Unlock()
		found := []note{}
		for _, n := range sorted() {
			if matches(n, values) {
				found = append(found, n)
			}
		}
		answer(w, 200, page(found, query.Cursor, query.Limit))
	})
	// create: PacketFence already checked api.create.can ("create syslog")
	mux.HandleFunc("POST /notes", func(w http.ResponseWriter, r *http.Request) {
		var n note
		if err := json.NewDecoder(r.Body).Decode(&n); err != nil || n.ID == "" {
			answer(w, 422, map[string]any{"message": "A name is required", "errors": []map[string]string{{"field": "id", "message": "required"}}, "status": 422})
			return
		}
		lock.Lock()
		defer lock.Unlock()
		if _, found := notes[n.ID]; found {
			message(w, 409, "This note already exists")
			return
		}
		notes[n.ID] = n
		log.Printf("note %s created by %s", n.ID, adminOf(r).Username)
		answer(w, 201, map[string]any{"id": n.ID, "message": "Note created", "status": 201})
	})
	// item
	mux.HandleFunc("GET /notes/{id}", func(w http.ResponseWriter, r *http.Request) {
		lock.Lock()
		defer lock.Unlock()
		n, found := notes[r.PathValue("id")]
		if !found {
			message(w, 404, "No such note")
			return
		}
		answer(w, 200, map[string]any{"item": n, "status": 200})
	})
	// update (PATCH): PacketFence already checked api.update.can
	mux.HandleFunc("PATCH /notes/{id}", func(w http.ResponseWriter, r *http.Request) {
		id := r.PathValue("id")
		lock.Lock()
		defer lock.Unlock()
		n, found := notes[id]
		if !found {
			message(w, 404, "No such note")
			return
		}
		if err := json.NewDecoder(r.Body).Decode(&n); err != nil {
			message(w, 422, "Invalid JSON")
			return
		}
		n.ID = id
		notes[id] = n
		answer(w, 200, map[string]any{"message": "Note updated", "status": 200})
	})
	// delete: PacketFence already checked api.delete.can
	mux.HandleFunc("DELETE /notes/{id}", func(w http.ResponseWriter, r *http.Request) {
		lock.Lock()
		defer lock.Unlock()
		id := r.PathValue("id")
		if _, found := notes[id]; !found {
			message(w, 404, "No such note")
			return
		}
		delete(notes, id)
		answer(w, 200, map[string]any{"message": "Note deleted", "status": 200})
	})
	return mux
}

// the "value"s of a search query of the UI
func searchValues(raw json.RawMessage) []string {
	values := []string{}
	var walk func(v any)
	walk = func(v any) {
		switch t := v.(type) {
		case map[string]any:
			if s, ok := t["value"].(string); ok && s != "" {
				values = append(values, strings.ToLower(s))
			}
			for _, child := range t {
				walk(child)
			}
		case []any:
			for _, child := range t {
				walk(child)
			}
		}
	}
	var v any
	json.Unmarshal(raw, &v)
	walk(v)
	return values
}

func matches(n note, values []string) bool {
	for _, v := range values {
		if !strings.Contains(strings.ToLower(n.ID+" "+n.Text), v) {
			return false
		}
	}
	return true
}

func main() {
	listen := flag.String("listen", "127.0.0.1:8092", "the address the service listens on")
	name := flag.String("name", "notes-go", "the plugin name, the id of its manifest")
	host := flag.String("host", "", "the host PacketFence reaches the service at (default: the host of -listen)")
	port := flag.Int("port", 0, "the port PacketFence reaches the service at (default: the port of -listen)")
	tlsCert := flag.String("tls-cert", "", "certificate (PEM) to serve HTTPS: required unless PacketFence reaches the service on its loopback")
	tlsKey := flag.String("tls-key", "", "private key (PEM) of -tls-cert")
	register := flag.Bool("register", true, "register with PacketFence (false: register with register.pl yourself)")
	flag.Parse()

	listener, err := net.Listen("tcp", *listen)
	if err != nil {
		log.Fatal(err)
	}
	lhost, lport, _ := net.SplitHostPort(listener.Addr().String())
	r := uiplugins.Registration{Name: *name, Host: *host, Port: *port}
	if r.Host == "" {
		r.Host = lhost
	}
	if r.Port == 0 {
		r.Port, _ = strconv.Atoi(lport)
	}
	if err := r.Validate(); err != nil {
		log.Fatal(err)
	}
	if !uiplugins.IsLoopback(r.Host) && *tlsCert == "" {
		log.Fatalf("PacketFence reaches %s over HTTPS: -tls-cert and -tls-key are required", r.Host)
	}

	server := &http.Server{Handler: routes(), ReadHeaderTimeout: 10 * time.Second}
	go func() {
		var serveErr error
		if *tlsCert != "" {
			serveErr = server.ServeTLS(listener, *tlsCert, *tlsKey)
		} else {
			serveErr = server.Serve(listener)
		}
		if serveErr != nil && !errors.Is(serveErr, http.ErrServerClosed) {
			log.Fatal(serveErr)
		}
	}()

	// register once the service answers: the credentials of the database
	// come from the PacketFence configuration
	if *register {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		if err := uiplugins.Register(ctx, r); err != nil {
			log.Fatal(err)
		}
		cancel()
	}
	log.Printf("UI plugin %s at %s", r.Name, r.BaseURL())

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGTERM, syscall.SIGINT)
	<-stop

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if *register {
		if err := uiplugins.Deregister(ctx, r.Name); err != nil {
			log.Print(err)
		}
	}
	server.Shutdown(ctx)
	log.Printf("UI plugin %s stopped", r.Name)
}
