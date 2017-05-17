package firewallsso

import (
	"math/rand"
	"testing"
)

func TestJsonRpcRequestBody(t *testing.T) {
	jr := JSONRPC{}
	rand.Seed(1)
	body, _ := jr.getRequestBody("action", sampleInfo, 86400)
	expected := `{"jsonrpc":"2.0","method":"action","params":{"user":"lzammit","mac":"00:11:22:33:44:55","ip":"1.2.3.4","role":"default","timeout":86400},"id":5577006791947779410}`
	if string(body) != expected {
		t.Errorf("Unexpected request body was created. %s instead of %s", string(body), expected)
	}
}
