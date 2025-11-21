// package wip provides structs and helpers to manage the API HTTP responses
package wip

import (
	"encoding/json"
	"net/http"
	"reflect"
	"strings"
)

// ApiError struct contains data to manage API response error
type ApiError struct {
	Code    int    `json:"code,omitempty"`  // custom code, 0 not used
	Field   string `json:"field,omitempty"` // what field is the error about
	Op      string `json:"op,omitempty"`    // mostly used for the query API
	Message string `json:"message"`         // message to show to the caller
}

// ApiPagination struct contains data to manage pagination
// Cursor will mostly be of type int or string
type ApiPagination struct {
	// omit useless fields for now, legacy Perl does not use them
	Count      *int // `json:"count,omitempty"`      // items in the current page
	Limit      *int // `json:"limit,omitempty"`      // number of items per page
	Total      *int // `json:"total,omitempty"`      // total number of items
	NextCursor any  `json:"nextCursor,omitempty"` // starting value(s) of next page
	PrevCursor any  `json:"prevCursor,omitempty"` // startgin value(s) of previous page
}

// ApiBody struct contains data to be serialized into the HTTP response
// The only requirements is that [Payload] must be marshalable
type ApiBody struct {
	ApiPagination            // optionnal if not set
	Payload       any        `json:"__PAYLOAD__,omitempty"` // data asked here, renamed at runtime
	Errors        []ApiError `json:"errors,omitempty"`      // optionnal list of all errors
	Message       string     `json:"message,omitempty"`     // Optionnal informative message
	Status        int        `json:"status"`                // HTTP response status
	tag           string     // tag to replace the 'Payload' name, or empty to keep struct fields
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

func (body *ApiBody) ResponseItem(w http.ResponseWriter, status int, payload any) error {
	body.Status = status
	data, err := body.response(w, payload, "item")
	if err != nil {
		return err
	}
	_, err = w.Write(data)
	return err
}

func (body *ApiBody) ResponseItems(w http.ResponseWriter, status int, payload any) error {
	body.Status = status
	data, err := body.response(w, payload, "items")
	if err != nil {
		return err
	}
	_, err = w.Write(data)
	return err
}

func (body *ApiBody) ResponseRaw(w http.ResponseWriter, status int, payload any) error {
	body.Status = status
	data, err := body.response(w, payload, "")
	if err != nil {
		return err
	}
	_, err = w.Write(data)
	return err
}

func (body *ApiBody) ResponseError(w http.ResponseWriter, status int) error {
	body.Status = status
	// Always set first error message as main message, need for compatibility
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

func (body *ApiBody) AddError(err ApiError) {
	body.Errors = append(body.Errors, err)
}

func (body *ApiBody) AddFieldError(field, message string) {
	body.AddError(ApiError{Field: field, Message: message})
}

func (body *ApiBody) AddMessageError(message string) {
	body.AddError(ApiError{Message: message})
}

func (body *ApiBody) QuickError(w http.ResponseWriter, status int, message string) error {
	body.AddMessageError(message)
	return body.ResponseError(w, status)
}

func (body *ApiBody) QuickFieldError(w http.ResponseWriter, status int, field, message string) error {
	body.AddFieldError(field, message)
	return body.ResponseError(w, status)
}

func (body *ApiBody) response(w http.ResponseWriter, payload any, tag string) ([]byte, error) {
	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
	w.WriteHeader(body.Status)
	body.Payload = payload
	body.tag = tag
	return json.Marshal(body)
}

func isEmptyValue(v *reflect.Value) bool {
	switch v.Kind() {
	case reflect.Array, reflect.Map, reflect.Slice, reflect.String:
		return v.Len() == 0
	case reflect.Bool,
		reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64,
		reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64, reflect.Uintptr,
		reflect.Float32, reflect.Float64,
		reflect.Interface, reflect.Pointer:
		return v.IsZero()
	default:
		return false
	}
}

func isZeroValue(v *reflect.Value) bool {
	return v.IsZero()
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
					if isEmptyValue(&fieldValue) {
						continue FieldLoop
					}
				} else if splitAlias[tagId] == "omitzero" {
					if isZeroValue(&fieldValue) {
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

// Simpler but less efficient version of renaming Payload at runtime, but 100% safe
//func (body *ApiBody) renamePayload(name string) error {
//	var tmp any
//	json.Unmarshal(body.rawResponse, &tmp)
//	data1 := tmp.(map[string]any)
//	data2 := data1["__PAYLOAD__"].(map[string]any)
//	subKey := slices.Collect(maps.Keys(data2))[0]
//	var newName string
//	if len(name) == 0 {
//		newName = subKey
//	} else {
//		newName = name
//	}
//	data1[newName] = data2[subKey]
//	delete(data1, "data")
//	body.rawResponse, _ = json.Marshal(data1)
//	return nil
//}
