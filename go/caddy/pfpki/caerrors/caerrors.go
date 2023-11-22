package caerrors

// caError is an internal error structure.
type CaError struct {
	Status     int
	Desc       string
	Retryafter int
}

// StatusCode returns the HTTP status code.
func (e CaError) StatusCode() int {
	return e.Status
}

// Error returns a human-readable description of the error.
func (e CaError) Error() string {
	return e.Desc
}

// RetryAfter returns the value in seconds after which the client should
// retry the request.
func (e CaError) RetryAfter() int {
	return e.Retryafter
}
