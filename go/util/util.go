package util

import (
	"fmt"
	"net"
	"runtime"
	"testing"
)

func CheckError(err error) {
	if err != nil {
		panic(err)
	}
}

func CheckTestError(t *testing.T, err error) {
	if err != nil {
		_, file, no, _ := runtime.Caller(1)
		t.Error(fmt.Sprintf("There was an error '%s' called from %s#%d", err, file, no))
	}
}

func NextIP(ip net.IP, inc uint) net.IP {
	i := ip.To4()
	v := uint(i[0])<<24 + uint(i[1])<<16 + uint(i[2])<<8 + uint(i[3])
	v += inc
	v3 := byte(v & 0xFF)
	v2 := byte((v >> 8) & 0xFF)
	v1 := byte((v >> 16) & 0xFF)
	v0 := byte((v >> 24) & 0xFF)
	return net.IPv4(v0, v1, v2, v3)
}

func MapKeys[K comparable, V any](m map[K]V) []K {
	keys := make([]K, 0, len(m))
	for k, _ := range m {
		keys = append(keys, k)
	}

	return keys
}
