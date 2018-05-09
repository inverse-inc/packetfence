package unifiedapierrors

import (
	"encoding/json"
	"net/http"

	"github.com/inverse-inc/packetfence/go/sharedutils"
)

type UnifiedAPIError struct {
	Message string `json:"message"`
}

func Error(res http.ResponseWriter, msg string, statusCode int) {
	apiError := UnifiedAPIError{Message: msg}
	data, err := json.Marshal(apiError)
	sharedutils.CheckError(err)

	http.Error(res, string(data), statusCode)
}
