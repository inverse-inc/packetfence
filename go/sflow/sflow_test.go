package sflow

import (
	"encoding/hex"
	"testing"
)

func TestHeader(t *testing.T) {
	packet_in_hex := "0000000500000001ac152311000000010000019f673dd71000000001000000020000006c000021250000040c0000000100000001000000580000040c000000060000000005f5e100000000010000000300000000018c2ccc00009b83000290160001f6730000000000000000000000000000000000533dc10000a0b700002187000008d7000000000000000000000000"
	raw_bytes, err := hex.DecodeString(packet_in_hex)
	if err != nil {
		t.Fatal(err)
	}

	h := Header{}
	next := h.Parse(raw_bytes)
	CheckUint32(t, "h.Version", h.Version, 5)
	CheckUint32(t, "h.AddressType", h.AddressType, 1)
	CheckUint32(t, "h.SubAgentID", h.SubAgentID, 1)
	CheckUint32(t, "h.SequenceNumber", h.SequenceNumber, 415)
	CheckUint32(t, "h.SysUptime", h.SysUptime, 1732106000)
	CheckUint32(t, "h.NumSamples", h.NumSamples, 1)

	df := DataFormat{}
	next = df.Parse(next)
	CheckUint32(t, "df.Format", df.Format, 2)
	CheckUint32(t, "df.Length", df.Length, 108)
	cs := CountersSample{}
	next = cs.Parse(next)
	CheckUint32(t, "cs.SequenceNumber", cs.SequenceNumber, 8485)
	CheckUint32(t, "cs.SourceId", cs.SourceId, 1036)
	CheckUint32(t, "cs.NumSamples", cs.NumSamples, 1)
	next = df.Parse(next)
	CheckUint32(t, "df.Format", df.Format, 1)
	CheckUint32(t, "df.Length", df.Length, 88)
	ic := IfCounter{}
	next = ic.Parse(next)
	CheckUint32(t, "ic.Index", ic.Index, 1036)
	CheckUint32(t, "ic.Type", ic.Type, 6)
	CheckUint64(t, "ic.Speed", ic.Speed, 100000000)
	CheckUint32(t, "ic.Direction", ic.Direction, 1)
	CheckUint32(t, "ic.Status", ic.Status, 3)
	CheckUint64(t, "ic.InOctets", ic.InOctets, 25963724)
	CheckUint32(t, "ic.InUcastPkts", ic.InUcastPkts, 39811)
	CheckUint32(t, "ic.InMulticastPkts", ic.InMulticastPkts, 167958)
	CheckUint32(t, "ic.InBroadcastPkts", ic.InBroadcastPkts, 128627)
	CheckUint32(t, "ic.InDiscards", ic.InDiscards, 0)
	CheckUint32(t, "ic.InErrors", ic.InErrors, 0)
	CheckUint32(t, "ic.InUnknownProtos", ic.InUnknownProtos, 0)
	CheckUint64(t, "ic.OutOctets", ic.OutOctets, 5455297)
	CheckUint32(t, "ic.OutUcastPkts", ic.OutUcastPkts, 41143)
	CheckUint32(t, "ic.OutMulticastPkts", ic.OutMulticastPkts, 8583)
	CheckUint32(t, "ic.OutBroadcastPkts", ic.OutBroadcastPkts, 2263)
	CheckUint32(t, "ic.OutDiscards", ic.OutDiscards, 0)
	CheckUint32(t, "ic.OutErrors", ic.OutErrors, 0)
	CheckUint32(t, "ic.PromiscuousMode", ic.PromiscuousMode, 0)
}

func CheckUint32(t *testing.T, name string, got, expected uint32) {
	if got != expected {
		t.Errorf("%s: Got %d expected %d", name, got, expected)
	}
}

func CheckUint64(t *testing.T, name string, got, expected uint64) {
	if got != expected {
		t.Errorf("%s: Got %d expected %d", name, got, expected)
	}
}
