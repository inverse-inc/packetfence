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

func fetchSocket(payload string) []byte {
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

func fetchDecodeSocket(o PfconfigObject) {
	or := reflect.TypeOf(o).Elem()
	var method, ns string
	if field, ok := or.FieldByName("PfconfigNS"); ok {
		ns = field.Tag.Get("ns")
	} else {
		panic("Missing PfConfigNS for " + or.String())
	}
	if field, ok := or.FieldByName("PfconfigMethod"); ok {
		method = field.Tag.Get("method")
		if method == "hash_element" {
			if field, ok = or.FieldByName("PfconfigHashNS"); ok {
				ns = ns + ";" + field.Tag.Get("ns")
			} else {
				panic("Missing PfconfigHashNS for object that declares method hash_element. Object type: " + or.String())
			}
		}
	} else {
		panic("Missing PfconfigMethod for " + or.String())
	}

	fmt.Printf("Method: %s, NS: %s \n", method, ns)
	jsonResponse := fetchSocket(fmt.Sprintf(`{"method":"%s", "key":"%s","encoding":"json"}`+"\n", method, ns))
	receiver := &PfconfigResponse{}
	decodeJsonObject(jsonResponse, receiver)

	b, _ := receiver.Element.MarshalJSON()
	decodeJsonObject(b, &o)
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
