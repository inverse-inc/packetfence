// package api provides structs and helpers to manage the API HTTP responses
package api

import (
	"encoding/json"
	"net/http"
	"reflect"
	"strings"

	"github.com/inverse-inc/packetfence/go/util"
)

// ApiErrorNew struct contains data to manage API response error. TODO: rename to ApiError when refactor older endpoints
type ApiErrorNew struct {
	Code    *int   `json:"code,omitempty"`  // custom code, 0 not used
	Field   string `json:"field,omitempty"` // what field is the error about
	Op      string `json:"op,omitempty"`    // mostly used for the query API
	Message string `json:"message"`         // message to show to the caller
}

func (e *ApiErrorNew) Error() string {
	return e.Message
}

// ApiPagination struct contains data to manage pagination
// Cursors will mostly be of type int or string or array
type ApiPagination struct {
	//Count      *int `json:"count,omitempty"`      // items in the current page, not used yet
	//Limit      *int `json:"limit,omitempty"`      // number of items per page, not used yet
	//Total      *int `json:"total,omitempty"`      // total number of items, not used yet
	NextCursor any `json:"nextCursor,omitempty"` // starting value(s) of next page
	PrevCursor any `json:"prevCursor,omitempty"` // starting value(s) of previous page
}

// ApiBody struct contains data to be serialized into the HTTP response
// The only requirements is that [Payload] must be marshalable
type ApiBody struct {
	ApiPagination               // optionnal if not set
	Errors        []ApiErrorNew `json:"errors,omitempty"`      // optionnal list of all errors
	Message       string        `json:"message,omitempty"`     // Optionnal informative message
	Status        int           `json:"status"`                // HTTP response status
	Payload       any           `json:"__PAYLOAD__,omitempty"` // payload here, renamed at runtime
	tag           string        // tag to replace the 'Payload' name, or empty to keep struct fields
}

// ApiResponse, public, used by clients
type ApiResponse struct {
	Errors  []ApiErrorNew `json:"errors,omitempty"`  // optionnal list of all errors
	Message string        `json:"message,omitempty"` // Optionnal informative message, contains any error too
	Status  int           `json:"status"`            // HTTP response status
}

// ApiResponsePagination, public, used by clients
type ApiResponsePagination struct {
	ApiPagination
	ApiResponse
}

// Override marshalization. We need to rename the payload field at runtime
func (body *ApiBody) MarshalJSON() ([]byte, error) {
	data := make(map[string]any)
	if body.Payload != nil {
		if len(body.tag) != 0 {
			data[body.tag] = body.Payload
		} else {
			marshal(data, body.Payload)
		}
	}
	body.Payload = nil // we already parsed it
	marshal(data, body)
	return json.Marshal(data)
}

// ResponseItem, used when you return a single Item without pagination
func (body *ApiBody) ResponseItem(w http.ResponseWriter, status int, payload any) error {
	body.Status = status
	data, err := body.response(w, payload, "item")
	if err != nil {
		return err
	}
	_, err = w.Write(data)
	return err
}

// ResponseItems, used when you return multiple Items with pagination
func (body *ApiBody) ResponseItems(w http.ResponseWriter, status int, payload any) error {
	body.Status = status
	data, err := body.response(w, payload, "items")
	if err != nil {
		return err
	}
	_, err = w.Write(data)
	return err
}

// ResponseRaw, used when you return a custom field. It used the name of the nested struct
// For example, this struct will use "y" as json field name for the payload:
//
//	type X struct {
//	 Y Type `json:"y"`
//	}
//
// ... will become:
// { "y": ... }
func (body *ApiBody) ResponseRaw(w http.ResponseWriter, status int, payload any) error {
	body.Status = status
	data, err := body.response(w, payload, "")
	if err != nil {
		return err
	}
	_, err = w.Write(data)
	return err
}

// ResponseError, used when you want to return error(s)
func (body *ApiBody) ResponseError(w http.ResponseWriter, status int) error {
	body.Status = status
	// Always set first error message as main message, needed for compatibility
	if len(body.Message) == 0 {
		if len(body.Errors) > 0 {
			body.Message = body.Errors[0].Message
		} else { // default value based on status code, but you should always have at least one error
			body.Message = http.StatusText(status)
		}
	}
	data, err := body.response(w, nil, "")
	if err != nil {
		return err
	}
	_, err = w.Write(data)
	return err
}

// AddError, add a single error into the response
func (body *ApiBody) AddError(err ApiErrorNew) {
	body.Errors = append(body.Errors, err)
}

// AddFieldError, helper to add an error with a field into the response
func (body *ApiBody) AddFieldError(field, message string) {
	body.AddError(ApiErrorNew{Field: field, Message: message})
}

// AddMessageError, helper to add an error with a message only into the response
func (body *ApiBody) AddMessageError(message string) {
	body.AddError(ApiErrorNew{Message: message})
}

// QuickError, helper to add a single message error and prepare response at the same time
func (body *ApiBody) QuickError(w http.ResponseWriter, status int, message string) error {
	body.AddMessageError(message)
	return body.ResponseError(w, status)
}

// QuickFieldError, helper to add a single field error and prepare response at the same time
func (body *ApiBody) QuickFieldError(w http.ResponseWriter, status int, field, message string) error {
	body.AddFieldError(field, message)
	return body.ResponseError(w, status)
}

// response, internal real response work. [tag] is used to know how to rename the payload field.
func (body *ApiBody) response(w http.ResponseWriter, payload any, tag string) ([]byte, error) {
	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
	w.WriteHeader(body.Status)
	body.Payload = payload
	body.tag = tag
	return json.Marshal(body)
}

// based on json/encode: https://cs.opensource.google/go/go/+/refs/tags/go1.25.4:src/encoding/json/encode.go
func marshal(fields map[string]any, data any) {
	valueData := reflect.ValueOf(data)
	for ; valueData.Kind() == reflect.Ptr; valueData = reflect.Indirect(valueData) {
	} // dereference until the real value
	valueType := reflect.TypeOf(data)
	if valueType.Kind() == reflect.Ptr {
		valueType = valueType.Elem()
	}
FieldLoop:
	for i := 0; i < valueType.NumField(); i++ {
		fieldType := valueType.Field(i)
		fieldValue := valueData.Field(i)
		if !fieldType.IsExported() {
			continue
		}
		if fieldValue.Kind() == reflect.Struct && fieldType.Anonymous {
			// recursive call for embedded structs
			marshal(fields, fieldValue.Interface())
			continue
		}
		if alias, ok := fieldType.Tag.Lookup("json"); ok {
			splitAlias := strings.Split(alias, ",") // omitempty, omitzero, -
			for tagId := 1; tagId < len(splitAlias); tagId++ {
				if splitAlias[tagId] == "omitempty" {
					if util.IsEmptyValue(&fieldValue) {
						continue FieldLoop
					}
				} else if splitAlias[tagId] == "omitzero" {
					if util.IsZeroValue(&fieldValue) {
						continue FieldLoop
					}
				} else if splitAlias[tagId] == "-" {
					continue FieldLoop
				}
			}
			if len(splitAlias[0]) == 0 {
				splitAlias[0] = "Field"
			}
			fields[splitAlias[0]] = fieldValue.Interface()
		}
	}
}
