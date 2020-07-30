package glpclient

import (
	"context"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/url"
	"sync/atomic"
	"time"

	"github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

const (
	DEFAULT_TIMEOUT   = 30
	DEFAULT_REATTEMPT = 30
)

type PollResponse struct {
	Events    []PollEvent `json:"events"`
	Timestamp int64       `json:"timestamp"`
}

// Taken from https://github.com/jcuga/golongpoll/blob/master/events.go
type PollEvent struct {
	// Timestamp is milliseconds since epoch to match javascrits Date.getTime()
	Timestamp int64  `json:"timestamp"`
	Category  string `json:"category"`
	// NOTE: Data can be anything that is able to passed to json.Marshal()
	Data json.RawMessage `json:"data"`
}

type Client struct {
	path     string
	category string
	// Timeout controls the timeout in all the requests, can be changed after instantiating the client
	Timeout uint64
	// Reattempt controls the amount of time the client waits to reconnect to the server after a failure
	Reattempt time.Duration
	// Will get all the events data
	EventsChan chan PollEvent
	// Flag that tracks the current run ID
	runID uint64
	// The HTTP client to perform the requests, any changes on this should be done prior to starting the client the first time
	APIClient *unifiedapiclient.Client

	// Whether or not logging should be enabled
	LoggingEnabled bool

	// Private+Public key to use to use a private channel
	PrivateKey [32]byte
	PublicKey  [32]byte
}

func NewClient(apiClient *unifiedapiclient.Client, path string, category string) *Client {
	return &Client{
		path:           path,
		category:       category,
		Timeout:        DEFAULT_TIMEOUT,
		Reattempt:      DEFAULT_REATTEMPT * time.Second,
		EventsChan:     make(chan PollEvent),
		APIClient:      apiClient,
		LoggingEnabled: true,
	}
}

func (c *Client) Start() {
	if c.LoggingEnabled {
		log.Println("Now observing changes on", c.path)
	}

	atomic.AddUint64(&(c.runID), 1)
	currentRunID := atomic.LoadUint64(&(c.runID))

	go func(runID uint64, path string) {
		since := time.Now().Unix() * 1000
		for {
			pr, err := c.fetchEvents(since)

			if err != nil {
				if c.LoggingEnabled {
					log.Println(err)
					log.Printf("Reattempting to connect to %s in %d seconds", path, c.Reattempt)
				}
				time.Sleep(c.Reattempt)
				continue
			}

			// We check that its still the same runID as when this goroutine was started
			clientRunID := atomic.LoadUint64(&(c.runID))
			if clientRunID != runID {
				if c.LoggingEnabled {
					log.Printf("Client on path %s has been stopped, not sending events", path)
				}
				return
			}

			if len(pr.Events) > 0 {
				if c.LoggingEnabled {
					log.Println("Got", len(pr.Events), "event(s) from path", path)
				}
				for _, event := range pr.Events {
					since = event.Timestamp
					c.EventsChan <- event
				}
			} else {
				// Only push timestamp forward if its greater than the last we checked
				if pr.Timestamp > since {
					since = pr.Timestamp
				}
			}
		}
	}(currentRunID, c.path)
}

func (c *Client) Stop() {
	// Changing the runID will have any previous goroutine ignore any events it may receive
	atomic.AddUint64(&(c.runID), 1)
}

// Call the longpoll server to get the events since a specific timestamp
func (c Client) fetchEvents(since int64) (PollResponse, error) {
	if c.LoggingEnabled {
		log.Println("Checking for changes events since", since, "on URL", c.path)
	}

	query := url.Values{}
	if c.PrivateKey != "" && c.PublicKey != "" {
		shared := remoteclients.SharedSecret(priv, handler.publicKey)
		challenge := make([]byte, 8)
		binary.LittleEndian.PutUint64(challenge, uint64(time.Now().Unix()))
		encryptedChallenge, err := remoteclients.EncryptMessage(shared[:], challenge)
		sharedutils.CheckError(err)
		query.Set("auth", base64.URLEncoding.EncodeToString(encryptedChallenge))
	} else {
		query.Set("category", c.category)
	}
	query.Set("since_time", fmt.Sprintf("%d", since))
	query.Set("timeout", fmt.Sprintf("%d", c.Timeout))
	rawQuery := query.Encode()

	var pr PollResponse
	err := c.APIClient.Call(context.Background(), "GET", c.path+`?`+rawQuery, &pr)
	if err != nil {
		msg := fmt.Sprintf("Error while connecting to %s to observe changes. Error was: %s", c.path, err)
		return PollResponse{}, errors.New(msg)
	}

	return pr, nil
}
