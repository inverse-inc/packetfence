package acme

import "net/http"

// Test-only knob: swap the http-01 validator's transport. Tests use
// a mock RoundTripper so the validator runs through real net/http but
// lands on a synthetic responder. Keeping the indirection in this
// file (instead of exporting the raw var) means the production
// package surface stays unchanged.
// SetHTTP01Client swaps the http-01 validator's transport for the
// supplied client (typically backed by a mock RoundTripper). Returns
// the previous value so the test can restore it via t.Cleanup.
func SetHTTP01Client(c *http.Client) *http.Client {
	prev := http01Client
	http01Client = c
	return prev
}
