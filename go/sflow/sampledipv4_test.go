package sflow

import (
	"encoding/hex"
	"github.com/go-test/deep"
	"testing"
)

func TestParseFromEthernetHeader(t *testing.T) {
	header_hex := "8ee6cef957743e5b354b3a7208004500003c000040004006258f0a0000960a0000980050cc91323bdb526c0698c3a01216a0c6200000020405b40402080a3ed981073ed9780e010303070000"
	raw_bytes, err := hex.DecodeString(header_hex)
	if err != nil {
		t.Fatal(err)
	}

	sampledIPv4 := &SampledIPV4{}
	sampledIPv4.ParseFromIPHeader(raw_bytes[14:])
	if diff := deep.Equal(
		sampledIPv4,
		&SampledIPV4{
			Protocol: 6,
			SrcPort:  80,
			DstPort:  52369,
			SrcIP:    [4]byte{10, 0, 0, 150},
			DstIP:    [4]byte{10, 0, 0, 152},
		}); diff != nil {
		t.Error(diff)
	}

}
