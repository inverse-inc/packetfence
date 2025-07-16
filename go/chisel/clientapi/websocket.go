package clientapi

import (
	"bufio"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/nxadm/tail"
)

type Client struct {
	socket *websocket.Conn
	send   chan []byte
	done   chan struct{}
}

type Broadcaster struct {
	clients    map[*Client]bool
	broadcast  chan string
	register   chan *Client
	unregister chan *Client
	mu         sync.RWMutex
	done       chan struct{}
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

type LogFile struct {
	Path string `json:"logfile"`
	N    int    `json:"n"`
}

var LogFiles = map[string]string{
	"fingerbank-collector": "/usr/local/collector-remote/logs/fingerbank-collector.log",
	"ntlm-auth-api":        "/usr/local/collector-remote/logs/ntlm-auth-api.log",
	"pfconnector-remote":   "/usr/local/pfconnector-remote/logs/fingerbank-collector.log",
}

func newBroadcaster() *Broadcaster {
	return &Broadcaster{
		broadcast:  make(chan string),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		clients:    make(map[*Client]bool),
		done:       make(chan struct{}),
	}
}

func readLastNLines(fileName string, n int) ([]string, error) {
	file, err := os.Open(fileName)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	lines := make([]string, 0)

	for scanner.Scan() {
		lines = append(lines, scanner.Text())
		if len(lines) > n {
			lines = lines[1:]
		}
	}

	if scanner.Err() != nil {
		return nil, scanner.Err()
	}

	return lines, nil
}

func (b *Broadcaster) initialRead(client *Client, filePath string, n int) {
	lines, err := readLastNLines(filePath, n)
	if err != nil {
		log.Println(err)
		return
	}

	b.mu.RLock()
	_, exists := b.clients[client]
	b.mu.RUnlock()

	if exists {
		select {
		case client.send <- []byte(strings.Join(lines, "\n")):

		case <-client.done:
			return
		case <-time.After(5 * time.Second):
			log.Println("Timeout lors de l'envoi des lignes initiales")
			return
		}
	}
}

func (b *Broadcaster) tailFile(filepath string) {
	t, err := tail.TailFile(
		filepath,
		tail.Config{Follow: true, Location: &tail.SeekInfo{Offset: 0, Whence: 2}},
	)
	if err != nil {
		log.Fatalf("tail file err: %v", err)
	}

	for {
		select {
		case line, ok := <-t.Lines:
			if !ok {
				return
			}
			if line.Text != "" {
				select {
				case b.broadcast <- line.Text:
				case <-b.done:
					return
				}
			}
		case <-b.done:
			t.Stop()
			return
		}
	}
}

func handleWebSocketConnection() http.HandlerFunc {
	return func(res http.ResponseWriter, req *http.Request) {

		targetFile := req.URL.Query().Get("logfile")

		if _, err := os.Stat(targetFile); os.IsNotExist(err) {
			http.Error(res, "logfile does not exist", http.StatusNotFound)
			return
		}

		if Logfile, exists := LogFiles[targetFile]; exists {
			targetFile = Logfile
		} else {
			log.Printf("Log file %s not found in predefined list, using provided path", targetFile)
			return
		}

		n := req.URL.Query().Get("line")
		Line, err := strconv.Atoi(n)

		if err != nil || Line <= 0 {
			Line = 10 // Default to last 10 lines if not specified
		}
		if Line > 1000 {
			Line = 1000 // Limit to last 1000 lines
		}

		broadcaster := newBroadcaster()
		go broadcaster.run()
		go broadcaster.tailFile(targetFile)

		ws, err := upgrader.Upgrade(res, req, nil)
		if err != nil {
			log.Println(err)
			broadcaster.close()
			return
		}

		client := &Client{
			socket: ws,
			send:   make(chan []byte, 256),
			done:   make(chan struct{}),
		}

		broadcaster.register <- client

		time.Sleep(10 * time.Millisecond)

		go broadcaster.initialRead(client, targetFile, Line)

		go func() {
			defer func() {
				close(client.done)
				broadcaster.unregister <- client
				ws.Close()
			}()

			ws.SetReadDeadline(time.Now().Add(60 * time.Second))
			ws.SetPongHandler(func(string) error {
				ws.SetReadDeadline(time.Now().Add(60 * time.Second))
				return nil
			})

			for {
				_, _, err := ws.ReadMessage()
				if err != nil {
					break
				}
			}
		}()

		go func() {
			defer ws.Close()
			ticker := time.NewTicker(54 * time.Second)
			defer ticker.Stop()

			for {
				select {
				case message, ok := <-client.send:
					ws.SetWriteDeadline(time.Now().Add(10 * time.Second))
					if !ok {
						ws.WriteMessage(websocket.CloseMessage, []byte{})
						return
					}
					if err := ws.WriteMessage(websocket.TextMessage, message); err != nil {
						return
					}
				case <-ticker.C:
					ws.SetWriteDeadline(time.Now().Add(10 * time.Second))
					if err := ws.WriteMessage(websocket.PingMessage, nil); err != nil {
						return
					}
				case <-client.done:
					return
				}
			}
		}()

		<-client.done
		broadcaster.close()
	}
}

func (b *Broadcaster) run() {
	for {
		select {
		case client := <-b.register:
			b.mu.Lock()
			b.clients[client] = true
			b.mu.Unlock()
			log.Printf("Client enregistré. Total: %d", len(b.clients))

		case client := <-b.unregister:
			b.mu.Lock()
			if _, ok := b.clients[client]; ok {
				delete(b.clients, client)
				close(client.send)
				log.Printf("Client désenregistré. Total: %d", len(b.clients))
			}
			b.mu.Unlock()

		case message := <-b.broadcast:
			b.mu.RLock()
			for client := range b.clients {
				select {
				case client.send <- []byte(message):
				default:
					delete(b.clients, client)
					close(client.send)
				}
			}
			b.mu.RUnlock()

		case <-b.done:
			return
		}
	}
}

func (b *Broadcaster) close() {
	close(b.done)

	b.mu.Lock()
	for client := range b.clients {
		close(client.send)
		client.socket.Close()
	}
	b.clients = make(map[*Client]bool)
	b.mu.Unlock()
}
