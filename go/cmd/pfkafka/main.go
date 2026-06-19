package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"time"

	"github.com/segmentio/kafka-go"
	"github.com/segmentio/kafka-go/sasl"
	"github.com/segmentio/kafka-go/sasl/plain"
)

const kafkaSSLDir = "/usr/local/pf/conf/kafka/ssl"

// buildTLSConfig assembles a *tls.Config for client mTLS against the broker.
// The client keypair (certPath/keyPath) is loaded when both are non-empty,
// enabling mutual TLS; caPath, when set, is used to verify the broker's server
// certificate. Any load failure is returned so the caller can fail loudly
// instead of silently falling back to plaintext.
func buildTLSConfig(certPath, keyPath, caPath, serverName string, skipVerify bool) (*tls.Config, error) {
	cfg := &tls.Config{
		MinVersion:         tls.VersionTLS12,
		InsecureSkipVerify: skipVerify,
	}

	if certPath != "" && keyPath != "" {
		cert, err := tls.LoadX509KeyPair(certPath, keyPath)
		if err != nil {
			return nil, fmt.Errorf("loading client keypair (%s, %s): %w", certPath, keyPath, err)
		}
		cfg.Certificates = []tls.Certificate{cert}
	}

	if caPath != "" {
		caPEM, err := os.ReadFile(caPath)
		if err != nil {
			return nil, fmt.Errorf("reading CA file %s: %w", caPath, err)
		}
		pool := x509.NewCertPool()
		if !pool.AppendCertsFromPEM(caPEM) {
			return nil, fmt.Errorf("no valid certificates found in CA file %s", caPath)
		}
		cfg.RootCAs = pool
	}

	if serverName != "" {
		cfg.ServerName = serverName
	}

	return cfg, nil
}

func main() {
	// to consume messages
	topic := "pfflows_events"
	user := ""
	pass := ""
	broker := "localhost:9095"
	useTLS := false
	certPath := kafkaSSLDir + "/cert.pem"
	keyPath := kafkaSSLDir + "/key.pem"
	caPath := kafkaSSLDir + "/ca.pem"
	tlsSkipVerify := false
	serverName := ""
	flag.StringVar(&topic, "topic", topic, "topic")
	flag.StringVar(&broker, "broker", broker, "broker")
	flag.StringVar(&user, "user", user, "user")
	flag.StringVar(&pass, "password", pass, "password")
	flag.BoolVar(&useTLS, "tls", useTLS, "enable TLS/mTLS for the broker connection")
	flag.StringVar(&certPath, "cert", certPath, "client certificate PEM (mTLS)")
	flag.StringVar(&keyPath, "key", keyPath, "client private key PEM (mTLS)")
	flag.StringVar(&caPath, "ca", caPath, "CA PEM used to verify the broker server certificate")
	flag.BoolVar(&tlsSkipVerify, "tls-skip-verify", tlsSkipVerify, "skip broker certificate verification (testing only)")
	flag.StringVar(&serverName, "server-name", serverName, "override the TLS server name (SNI/hostname verification)")
	flag.Parse()
	fmt.Fprintf(os.Stderr, "listening to %s on %s (tls=%t)\n", topic, broker, useTLS)
	var mechanism sasl.Mechanism
	if user != "" && pass != "" {
		mechanism = plain.Mechanism{
			Username: user,
			Password: pass,
		}
	}

	dialer := &kafka.Dialer{
		Timeout:       10 * time.Second,
		DualStack:     true,
		SASLMechanism: mechanism,
	}

	if useTLS {
		tlsConfig, err := buildTLSConfig(certPath, keyPath, caPath, serverName, tlsSkipVerify)
		if err != nil {
			log.Fatal("failed to configure TLS: ", err)
		}
		dialer.TLS = tlsConfig
	}
	//      partition := 0
	r := kafka.NewReader(kafka.ReaderConfig{

		Brokers:  []string{broker},
		Topic:    topic,
		GroupID:  "consumer-group-id" + topic,
		MaxBytes: 10e6, // 10MB
		Dialer:   dialer,
	})

	defer func() {
		if err := r.Close(); err != nil {
			log.Fatal("failed to close reader:", err)
		}
	}()

	ctx := context.Background()
	for {
		m, err := r.ReadMessage(ctx)
		if err != nil {
			// The reader was closed or the context was cancelled: nothing left to do.
			if errors.Is(err, io.EOF) || errors.Is(err, context.Canceled) {
				fmt.Fprintf(os.Stderr, "reader stopped: %s\n", err)
				break
			}
			// Transient errors (leader election, coordinator move, metadata
			// refresh, broker reconnects) are expected: kafka-go recovers on
			// the next read, so log and keep going instead of exiting.
			fmt.Fprintf(os.Stderr, "Error: %s\n", err)
			time.Sleep(time.Second)
			continue
		}
		//fmt.Printf("message at offset-partition %d-%d: %s = %s\n", m.Offset, m.Partition, string(m.Key), string(m.Value))
		fmt.Printf("%s\n", string(m.Value))
	}

}
