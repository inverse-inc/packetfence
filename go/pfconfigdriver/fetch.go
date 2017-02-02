package pfconfigdriver

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"github.com/Sereal/Sereal/Go/sereal"
	"io"
	"net"
	"reflect"
	//"github.com/davecgh/go-spew/spew"
)

const pfconfigSocketPath string = "/usr/local/pf/var/run/pfconfig.sock"

const pfconfigTestSocketPath string = "/usr/local/pf/var/run/pfconfig-test.sock"

var pfconfigSocketPathCache string

// Get the pfconfig socket path depending on whether or not we're in testing
// Since the environment is not bound to change at runtime, the socket path is computed once and cached in pfconfigSocketPathCache
// If the socket should be re-computed, empty out pfconfigSocketPathCache and run this function
func getPfconfigSocketPath() string {
	if pfconfigSocketPathCache != "" {
		// Do nothing, cache is populated, will be returned below
	} else if flag.Lookup("test.v") == nil {
		pfconfigSocketPathCache = pfconfigSocketPath
	} else {
		pfconfigSocketPathCache = pfconfigTestSocketPath
	}
	return pfconfigSocketPathCache
}

// Struct that encapsulates the necessary informations to do a query to pfconfig
type Query struct {
	encoding string
	method   string
	ns       string
	payload  string
}

// Get the payload to send to pfconfig based on the Query attributes
// Also sets the payload attribute at the same time
func (q *Query) GetPayload() string {
	q.payload = fmt.Sprintf(`{"method":"%s", "key":"%s","encoding":"%s"}`+"\n", q.method, q.ns, q.encoding)
	return q.payload
}

// Fetch data from the pfconfig socket for a string payload
// Returns the bytes received from the socket
func FetchSocket(ctx context.Context, payload string) []byte {
	c, err := net.Dial("unix", getPfconfigSocketPath())

	if err != nil {
		panic(err)
	}

	// Send our query in the socket
	fmt.Fprintf(c, payload)
	if err != nil {
		panic(err)
	}

	var buf bytes.Buffer
	buf.ReadFrom(c)

	// First 4 bytes are a little-endian representing the length of the payload
	var length uint32
	binary.Read(&buf, binary.LittleEndian, &length)

	// Read the response given the length provided by pfconfig
	response := make([]byte, length)
	buf.Read(response)

	// Validate the response has the length that was declared by pfconfig
	if uint32(len(response)) != length {
		panic(fmt.Sprintf("Got invalid length response from pfconfig %d expected, received %d", length, len(response)))
	}
	c.Close()
	return response
}

// Lookup the pfconfig metadata for a specific field
// If there is a non-zero value in the field, it will be taken
// Otherwise it will take the value in the val tag of the field
func metadataFromField(ctx context.Context, param PfconfigObject, fieldName string) string {
	var ov reflect.Value

	// PfconfigObject can be an actual struct or a reflect.Value
	// If its not a reflect.Value, we get the reflect.Value for that struct
	switch val := param.(type) {
	case reflect.Value:
		ov = val
	default:
		ov = reflect.ValueOf(param).Elem()
	}

	// We check if the field was set to a value as this will overide the value in the tag
	userVal := reflect.Value(ov.FieldByName(fieldName)).Interface()
	if userVal != "" {
		return userVal.(string)
	}

	ot := ov.Type()
	if field, ok := ot.FieldByName(fieldName); ok {
		// The val tag defines the «default» value the metadata field should have
		// If the val tag has a value of "-", then a user value was expected and this will panic
		val := field.Tag.Get("val")
		if val != "-" {
			return val
		} else {
			panic(fmt.Sprintf("No default value defined for %s on %s. User specified value is required.", fieldName, ot.String()))
		}
	} else {
		panic(fmt.Sprintf("Missing %s for %s", fieldName, ot.String()))
	}
}

// Decode the struct from bytes given an encoding
// Note that sereal doesn't properly work right now, so usage of JSON is advised
func decodeInterface(ctx context.Context, encoding string, b []byte, o interface{}) {
	switch encoding {
	case "json":
		decodeJsonInterface(ctx, b, o)
	case "sereal":
		decodeSerealInterface(ctx, b, o)
	default:
		panic(fmt.Sprintf("Unknown encoding %s", encoding))
	}
}

// Decode an array of bytes representing a json string into interface
// Panics if there is an error decoding the JSON data
func decodeJsonInterface(ctx context.Context, b []byte, o interface{}) {
	decoder := json.NewDecoder(bytes.NewReader(b))
	for {
		if err := decoder.Decode(&o); err == io.EOF {
			break
		} else if err != nil {
			panic(err)
		}
	}
}

// NOTE: This currently doesn't work so don't use it for now.
//       We will need to address this at some point in order to support Sereal payloads from pfconfig
//       For now use the JSON encoding
// Decode an array of bytes Sereal encoded into an interface
// Panics if there is an error decoding the Sereal payload
func decodeSerealInterface(ctx context.Context, b []byte, o interface{}) {
	decoder := sereal.NewDecoder()
	decoder.PerlCompat = false
	err := decoder.Unmarshal(b, o)
	if err != nil {
		panic(err)
	}
}

// Create a pfconfig query given a PfconfigObject
// Will extract the query information from the struct and will create the payload accordingly
// The struct should declare the following fields to be compatible
//		PfconfigNS - the pfconfig namespace to use (ex: resource::fqdn)
//		PfconfigMethod - the method to use while calling pfconfig (hash_element is a special case, see below)
//		PfconfigHashNS - the hash element key when using the hash_element method, this attribute has no effect when using any other method
func createQuery(ctx context.Context, o PfconfigObject) Query {
	query := Query{}
	query.ns = metadataFromField(ctx, o, "PfconfigNS")
	query.method = metadataFromField(ctx, o, "PfconfigMethod")
	if query.method == "hash_element" {
		query.ns = query.ns + ";" + metadataFromField(ctx, o, "PfconfigHashNS")
	}
	query.encoding = "json"
	return query
}

// Fetch and decode a namespace from pfconfig given a pfconfig compatible struct
// This cannot accept an interface and requires the struct to have been declared to its final type (so not created by the reflection)
func FetchDecodeSocketStruct(ctx context.Context, o PfconfigObject) error {
	return FetchDecodeSocket(ctx, o, reflect.Value{})
}

// Fetch and decode a namespace from pfconfig given a pfconfig compatible struct
// The proper reflect.Value must be passed to extract the pfconfig metadata from
func FetchDecodeSocketInterface(ctx context.Context, o PfconfigObject, reflectInfo reflect.Value) error {
	return FetchDecodeSocket(ctx, o, reflectInfo)
}

// Fetch and decode a namespace from pfconfig given a pfconfig compatible struct
// If reflectInfo is a valid reflect.Value, it will be used to extract the pfconfig metadata from it
// This will fetch the json representation from pfconfig and decode it into o
// o must be a pointer to the struct as this should be used by reference
func FetchDecodeSocket(ctx context.Context, o PfconfigObject, reflectInfo reflect.Value) error {
	var queryParam interface{}
	if reflectInfo.IsValid() {
		queryParam = reflectInfo
	} else {
		queryParam = o
	}
	query := createQuery(ctx, queryParam)
	jsonResponse := FetchSocket(ctx, query.GetPayload())
	if query.method == "keys" {
		if cs, ok := o.(*ConfigSections); ok {
			decodeInterface(ctx, query.encoding, jsonResponse, &cs.Keys)
		} else {
			panic("Wrong struct type for keys. Required ConfigSections")
		}
	} else {
		receiver := &PfconfigElementResponse{}
		decodeInterface(ctx, query.encoding, jsonResponse, receiver)
		if receiver.Element != nil {
			b, _ := receiver.Element.MarshalJSON()
			decodeInterface(ctx, query.encoding, b, &o)
		} else {
			return errors.New(fmt.Sprintf("Element in response was invalid. Response was: %s", jsonResponse))
		}
	}

	return nil
}
