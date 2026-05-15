package acme

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// http01Client is the HTTP transport used to fetch the device's
// well-known challenge response. Exposed as a package variable so tests
// can swap it for a transport that returns canned responses without
// real networking.
var http01Client = &http.Client{
	Timeout: 10 * time.Second,
}

// http01Validate performs the RFC 8555 §8.3 verification: GET
// http://<identifier>/.well-known/acme-challenge/<token> and confirm
// the response body equals "<token>.<accountKeyThumbprint>". Returns
// nil on success; the returned error message is safe to surface in an
// ACME problem document.
//
// The spec mandates HTTP (not HTTPS) on port 80; we honor that for
// compatibility with off-the-shelf ACME clients. Reverse proxies in
// front of the device's responder are the operator's problem.
func http01Validate(ctx context.Context, identifier, token, thumbprint string) error {
	if strings.TrimSpace(identifier) == "" {
		return errors.New("http-01: empty identifier")
	}
	if token == "" || thumbprint == "" {
		return errors.New("http-01: empty token or thumbprint")
	}
	url := "http://" + identifier + "/.well-known/acme-challenge/" + token
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return fmt.Errorf("http-01: build request: %w", err)
	}
	// RFC 8555 §8.3: the server SHOULD NOT follow redirects beyond
	// the configured limit (default 10); stdlib's default redirect
	// policy already caps at 10, which matches the spec.
	resp, err := http01Client.Do(req)
	if err != nil {
		return fmt.Errorf("http-01: fetch: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("http-01: HTTP %d from challenge URL", resp.StatusCode)
	}
	// Cap the body read so a hostile responder can't keep us reading
	// forever; the spec only ever expects a tiny `token.thumbprint`.
	body, err := io.ReadAll(io.LimitReader(resp.Body, 4096))
	if err != nil {
		return fmt.Errorf("http-01: read body: %w", err)
	}
	got := strings.TrimSpace(string(body))
	want := token + "." + thumbprint
	if got != want {
		return fmt.Errorf("http-01: key authorization mismatch")
	}
	return nil
}
