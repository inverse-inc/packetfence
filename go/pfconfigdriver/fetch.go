package pfconfigdriver

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"reflect"
	//"github.com/davecgh/go-spew/spew"
)

func FetchSocket(payload string) []byte {
	c, err := net.Dial("unix", "/usr/local/pf/var/run/pfconfig.sock")

	if err != nil {
		panic(err)
	}

	fmt.Fprintf(c, payload)
	if err != nil {
		panic(err)
	}
	var buf bytes.Buffer
	buf.ReadFrom(c)
	var length uint32
	binary.Read(&buf, binary.LittleEndian, &length)
	response := make([]byte, length)
	buf.Read(response)
	if uint32(len(response)) != length {
		panic(fmt.Sprintf("Got invalid length response from pfconfig %d expected, received %d", length, len(response)))
	}
	c.Close()
	return response
}

func metadataFromField(param PfconfigObject, fieldName string) string {
	var ov reflect.Value
	switch val := param.(type) {
	case reflect.Value:
		ov = val
	default:
		ov = reflect.ValueOf(param).Elem()
	}
	userVal := reflect.Value(ov.FieldByName(fieldName)).Interface()

	if userVal != "" {
		return userVal.(string)
	}

	ot := ov.Type()
	if field, ok := ot.FieldByName(fieldName); ok {
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

type Query struct {
	method  string
	ns      string
	payload string
}

func createQuery(o PfconfigObject) Query {
	query := Query{}
	query.ns = metadataFromField(o, "PfconfigNS")
	query.method = metadataFromField(o, "PfconfigMethod")
	if query.method == "hash_element" {
		query.ns = query.ns + ";" + metadataFromField(o, "PfconfigHashNS")
	}
	query.payload = fmt.Sprintf(`{"method":"%s", "key":"%s","encoding":"json"}`+"\n", query.method, query.ns)
	return query
}

func FetchDecodeSocketStruct(o PfconfigObject) {
	FetchDecodeSocket(o, reflect.Value{})
}

func FetchDecodeSocketInterface(o PfconfigObject, reflectInfo reflect.Value) {
	FetchDecodeSocket(o, reflectInfo)
}

func FetchDecodeSocket(o PfconfigObject, reflectInfo reflect.Value) {
	var queryParam interface{}
	if reflectInfo.IsValid() {
		queryParam = reflectInfo
	} else {
		queryParam = o
	}
	query := createQuery(queryParam)
	jsonResponse := FetchSocket(query.payload)
	if query.method == "keys" {
		if cs, ok := o.(*ConfigSections); ok {
			decodeJsonObject(jsonResponse, &cs.Keys)
		} else {
			panic("Wrong object type for keys. Required ConfigSections")
		}
	} else {
		receiver := &PfconfigElementResponse{}
		decodeJsonObject(jsonResponse, receiver)
		b, _ := receiver.Element.MarshalJSON()
		decodeJsonObject(b, &o)
	}

}

func FetchDecodeSocketReflect(o reflect.Value) {

}

func decodeJsonObject(b []byte, o interface{}) {
	decoder := json.NewDecoder(bytes.NewReader(b))
	for {
		if err := decoder.Decode(&o); err == io.EOF {
			break
		} else if err != nil {
			panic(err)
		}
	}
}
