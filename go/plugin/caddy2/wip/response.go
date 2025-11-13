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
	Code    int    `json:"code,omitzero"`   // custom code
	Field   string `json:"field,omitempty"` // what field is the error about
	Op      string `json:"op,omitempty"`    // mostly used for the query API
	Message string `json:"message"`         // message to show to the caller
}

// ApiPagination struct contains data to manage pagination
// Cursor will mostly be of type int or string
type ApiPagination struct {
	Count      int  `json:"count,omitzero"`       // items in the current page
	Limit      *int `json:"limit,omitempty"`      // number of items per page
	Total      *int `json:"total,omitempty"`      // total number of items
	NextCursor any  `json:"nextCursor,omitempty"` // starting value(s) of next page
	PrevCursor any  `json:"prevCursor,omitempty"` // startgin value(s) of previous page
}

// ApiBody struct contains data to be serialized into the HTTP response
// The only requirements is that [Payload] must be marshalable
type ApiBody struct {
	ApiPagination            // optionnal if not set
	Payload       any        `json:"__PAYLOAD__,omitempty"` // data asked here, rename at runtime
	Errors        []ApiError `json:"errors,omitempty"`      // optionnal list of all errors
	Message       string     `json:"message,omitempty"`     // Optionnal informative message
	Status        int        `json:"status"`                // HTTP response status
	rawResponse   []byte     // the actual response to be sent
	tag           string     // name to replace the Payload name, or empty to keep struct fields
}

func isEmptyValue(v reflect.Value) bool {
	switch v.Kind() {
	case reflect.Array, reflect.Map, reflect.Slice, reflect.String:
		return v.Len() == 0
	case reflect.Uintptr, reflect.Interface, reflect.Pointer:
		return v.IsZero()
	}
	return false
}

// based on json/encode: https://cs.opensource.google/go/go/+/refs/tags/go1.25.4:src/encoding/json/encode.go
// except:
// omitempty check only ptr, array, interface, slice, string, map
// not int/uint/float/bool anymore
// omitzero works the same: chekc for zero value of the type
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
					if isEmptyValue(fieldValue) {
						continue FieldLoop
					}
				} else if splitAlias[tagId] == "omitzero" {
					if fieldValue.IsZero() {
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

// Override marshalization
// We need to rename the payload field at runtime
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

func (body *ApiBody) marshalResponse(w http.ResponseWriter, payload any, tag string) error {
	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
	w.WriteHeader(body.Status)
	body.Payload = payload
	body.tag = tag
	var err error
	body.rawResponse, err = json.Marshal(body)
	return err
}

func (body *ApiBody) ResponseItem(w http.ResponseWriter, status int, payload any) {
	body.Status = status
	_ = body.marshalResponse(w, payload, "item")
	_, _ = w.Write(body.rawResponse)
}

func (body *ApiBody) ResponseItems(w http.ResponseWriter, status int, payload any) {
	body.Status = status
	_ = body.marshalResponse(w, payload, "items")
	_, _ = w.Write(body.rawResponse)
}

func (body *ApiBody) ResponseRaw(w http.ResponseWriter, status int, payload any) {
	body.Status = status
	_ = body.marshalResponse(w, payload, "")
	_, _ = w.Write(body.rawResponse)
}

func (body *ApiBody) AddError(err ApiError) {
	body.Errors = append(body.Errors, err)
}

func (body *ApiBody) Error(w http.ResponseWriter, status int) {
	body.Status = status
	_ = body.marshalResponse(w, nil, "")
	_, _ = w.Write(body.rawResponse)
}

func (body *ApiBody) ReplyError(w http.ResponseWriter, status int, err ApiError) {
	body.AddError(err)
	body.Error(w, status)
}

// Simpler but less efficient version, but 100% safe
//func (body *ApiBody) renamePayload(name string) error {
//	var tmp any
//	json.Unmarshal(body.rawResponse, &tmp)
//	data1 := tmp.(map[string]any)
//	data2 := data1["data"].(map[string]any)
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
