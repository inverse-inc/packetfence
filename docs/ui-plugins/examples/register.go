// An example of a Go plugin registering itself, with the PacketFence Go
// accessors (go/uiplugins): PacketFence reads its database credentials from
// its own configuration (pfconfig), the plugin never handles them.
//
// It registers the plugin once its service is up, and deregisters it when it
// receives SIGTERM or SIGINT (systemd stop, Kubernetes pod termination).
//
//	go run register.go -name hello -host hello.example -port 8090
package main

import (
	"context"
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/inverse-inc/packetfence/go/uiplugins"
)

func main() {
	r := uiplugins.Registration{}
	flag.StringVar(&r.Name, "name", "hello", "the plugin name, the id of its manifest")
	flag.StringVar(&r.Host, "host", "127.0.0.1", "the host PacketFence reaches the plugin service at")
	flag.IntVar(&r.Port, "port", 8090, "the port of the plugin service")
	flag.Parse()

	// catches the mistakes before touching the database
	if err := r.Validate(); err != nil {
		log.Fatal(err)
	}

	// start the plugin service here: it must serve /manifest.json before it
	// registers

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	if err := uiplugins.Register(ctx, r); err != nil {
		log.Fatal(err)
	}
	cancel()
	log.Printf("UI plugin %s registered at %s", r.Name, r.BaseURL())

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGTERM, syscall.SIGINT)
	<-stop

	ctx, cancel = context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := uiplugins.Deregister(ctx, r.Name); err != nil {
		log.Fatal(err)
	}
	log.Printf("UI plugin %s deregistered", r.Name)
}
