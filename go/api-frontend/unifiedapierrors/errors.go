package unifiedapierrors

import (
	"encoding/json"
	"net/http"

	"github.com/inverse-inc/go-utils/sharedutils"
)

type UnifiedAPIError struct {
	Status  int    `json:"status,omitempty"`
	Message string `json:"message"`
}

// Error replies with a JSON error like the rest of the API
func Error(res http.ResponseWriter, msg string, statusCode int) {
	apiError := UnifiedAPIError{Status: statusCode, Message: msg}
	data, err := json.Marshal(apiError)
	sharedutils.CheckError(err)

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.Header().Set("X-Content-Type-Options", "nosniff")
	res.WriteHeader(statusCode)
	res.Write(data)
}

// UnknownPath replies with a JSON 404 for a path that isn't an API route
func UnknownPath(res http.ResponseWriter, req *http.Request) {
	Error(res, "Unknown path "+req.URL.Path, http.StatusNotFound)
}

// MethodNotAllowed replies with a JSON 405 for an API route that doesn't accept the request method
func MethodNotAllowed(res http.ResponseWriter, req *http.Request) {
	Error(res, "Method "+req.Method+" not allowed on "+req.URL.Path, http.StatusMethodNotAllowed)
}

var methods = []string{http.MethodGet, http.MethodHead, http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete, http.MethodOptions}

// OtherMethodMatches tells whether the path of the request matches a route with another method, for the routers that can't tell
func OtherMethodMatches(req *http.Request, match func(method string) bool) bool {
	for _, method := range methods {
		if method != req.Method && match(method) {
			return true
		}
	}
	return false
}
