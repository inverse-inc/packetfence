package api

type ApiError struct {
	Message string        `json:"message"`
	Field   string        `json:"field,omitempty"`
	Op      string        `json:"op,omitempty"`
	Errors  []interface{} `json:"errors,omitempty"`
	Status  int           `json:"status"`
}

func (e *ApiError) Error() string {
	return e.Message
}

func NewApiError(status int, message string, errors []interface{}) *ApiError {
	return &ApiError{Status: status, Message: message, Errors: errors}
}

func NewFieldError(status int, field, message string, errors []interface{}) *ApiError {
	return &ApiError{Field: field, Message: message, Errors: errors, Status: status}
}

func NewOpError(status int, op, message string, errors []interface{}) *ApiError {
	return &ApiError{Op: op, Message: message, Errors: errors, Status: status}
}
