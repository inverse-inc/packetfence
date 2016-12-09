package pfconfigdriver

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"reflect"
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
	metadata := or.Field(0)
	jsonResponse := fetchSocket(fmt.Sprintf(`{"method":"%s", "key":"%s","encoding":"json"}`+"\n", metadata.Tag.Get("method"), metadata.Tag.Get("ns")))
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
