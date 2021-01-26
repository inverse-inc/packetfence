package sflow

import (
	"encoding/hex"
	"github.com/go-test/deep"
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
	ic.Parse(next)
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

func TestMultiSamples(t *testing.T) {
	packet_in_hex := "00000005000000010a0000fd000000000020036611a086300000000800000002000000a8000219a1000000070000000200000001000000580000000700000006000000003b9aca0000000001000000030000000014809050002359ac0000064a00005dd6000000000000000000000000000000012e67a1890024e2e700341d4f01d6a75600000000000000000000000000000002000000340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000840007ab6800000002000007d058b4258000000e7d000000020000000300000001000000010000005c000000010000004e000000040000004c8ee6cef957743e5b354b3a7208004500003c000040004006258f0a0000960a0000980050cc91323bdb526c0698c3a01216a0c6200000020405b40402080a3ed981073ed9780e01030307000000000002000000a8000219fe0000001800000002000000010000005800000018000000060000000005f5e10000000001000000030000001b4a3a4bbf0b7154bc0021d7730020a9f80000000000000001000000000000001be8ed06a30b95b84e0002552700000042000000000000000000000000000000020000003400000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000008c0007ab6900000002000007d058b42e1400000e7e000000020000000100000001000000010000006400000001000000580000000400000054f229017058253e5b354b3a72080045000046fa7c400040062b090a0000960a000097c1ec2bcb12ca960a47a6705e8018002e187300000101080a3ed981e93ed971d36765742073657373696f6e2e74696d650d0a000000010000008c0001e99100000001000007d014ac2e7a000004e5000000020000000100000001000000010000006400000001000000580000000400000054f229017058253e5b354b3a72080045000046fa7c400040062b090a0000960a000097c1ec2bcb12ca960a47a6705e8018002e187300000101080a3ed981e93ed971d36765742073657373696f6e2e74696d650d0a00000001000000b80006693200000014000003e81a265962000001760000001600000014000000010000000100000090000000010000041400000004000000800040101840190026bb527a5e0800450004025b120000401104910a0000460a0103023b5cacbc03eeeaacdae81d9001bf87f0a2ddda96f01ff701fa157785f459cc82c96f226297b2a63a60e3ebe40f271acffc3961cbb919960c2af6804a2696abe8ae9f47ba043c684a3a7738c6ce567b3fb293aa3c745e013073a0ef5835e900000001000000b80001420300000003000007d00babed440000064d0000000200000003000000010000000100000090000000010000015e00000004000000808ee6cef957743e5b354b3a7208004500014cf73e400040062d400a0000960a0000980050cd086c7076fe9f850c28801800361d5200000101080a3ed981e93ed978ca485454502f312e3120323030204f4b0d0a446174653a204672692c203235204a616e20323031332032323a32343a303720474d540d0a5365727665723a2000000001000000b800058b5300000018000003e8174be44a0000016a0000001700000018000000010000000100000090000000010000045a00000004000000800013c4559181004010184019080045000448c0cc0000ff119771d177232240af2a1e01f401f404340000000000000000000074103d54000c75e2a8277d1c099628cfa2df7d4e6627dd4229c75e539ad1055f15a580660589a47a7b3eee5afce4a8978d46509eda6956359a25ad62c53ed8b0b780c31c25bdca403add0e2cc5d9"
	raw_bytes, err := hex.DecodeString(packet_in_hex)
	if err != nil {
		t.Fatal(err)
	}
	h := Header{}
	next := h.Parse(raw_bytes)
	_ = next
	CheckUint32(t, "h.Version", h.Version, 5)
	CheckUint32(t, "h.AddressType", h.AddressType, 1)
	CheckUint32(t, "h.SubAgentID", h.SubAgentID, 0)
	CheckUint32(t, "h.SequenceNumber", h.SequenceNumber, 2098022)
	CheckUint32(t, "h.SysUptime", h.SysUptime, 295732784)
	CheckUint32(t, "h.NumSamples", h.NumSamples, 8)
	samples, err := h.ParseSamples(next)
	if err != nil {
		t.Errorf("%s", err)
	}

	if diff := deep.Equal(samples, []Sample{
		&CounterSamples{
			SequenceNumber: 137633,
			SourceId:       7,
			Records: []Counter{
				&IfCounter{
					Index:            7,
					Type:             6,
					Speed:            1000000000,
					Direction:        1,
					Status:           3,
					InOctets:         343969872,
					InUcastPkts:      2316716,
					InMulticastPkts:  1610,
					InBroadcastPkts:  24022,
					InDiscards:       0,
					InErrors:         0,
					InUnknownProtos:  0,
					OutOctets:        5073510793,
					OutUcastPkts:     2417383,
					OutMulticastPkts: 3415375,
					OutBroadcastPkts: 30844758,
					OutDiscards:      0,
					OutErrors:        0,
					PromiscuousMode:  0,
				},
				&EthernetCounter{
					AlignmentErrors: 0,
				},
			},
		},
		&FlowSample{
			SequenceNumber: 502632,
			SourceId:       2,
			SamplingRate:   2000,
			SamplePool:     1488201088,
			Drops:          3709,
			Input:          2,
			Output:         3,
			Records: []Flow{
				&SampledHeader{
					Protocol:       1,
					FrameLength:    78,
					PayloadRemoved: 4,
					Header:         []byte{0x8e, 0xe6, 0xce, 0xf9, 0x57, 0x74, 0x3e, 0x5b, 0x35, 0x4b, 0x3a, 0x72, 0x08, 0x00, 0x45, 0x00, 0x00, 0x3c, 0x00, 0x00, 0x40, 0x00, 0x40, 0x06, 0x25, 0x8f, 0x0a, 0x00, 0x00, 0x96, 0x0a, 0x00, 0x00, 0x98, 0x00, 0x50, 0xcc, 0x91, 0x32, 0x3b, 0xdb, 0x52, 0x6c, 0x06, 0x98, 0xc3, 0xa0, 0x12, 0x16, 0xa0, 0xc6, 0x20, 0x00, 0x00, 0x02, 0x04, 0x05, 0xb4, 0x04, 0x02, 0x08, 0x0a, 0x3e, 0xd9, 0x81, 0x07, 0x3e, 0xd9, 0x78, 0x0e, 0x01, 0x03, 0x03, 0x07, 0x00, 0x00},
				},
			},
		},
		&CounterSamples{
			SequenceNumber: 137726,
			SourceId:       24,
			Records: []Counter{
				&IfCounter{
					Index:            24,
					Type:             6,
					Speed:            100000000,
					Direction:        1,
					Status:           3,
					InOctets:         117209451455,
					InUcastPkts:      191976636,
					InMulticastPkts:  2217843,
					InBroadcastPkts:  2140664,
					InDiscards:       0,
					InErrors:         1,
					InUnknownProtos:  0,
					OutOctets:        119871964835,
					OutUcastPkts:     194361422,
					OutMulticastPkts: 152871,
					OutBroadcastPkts: 66,
					OutDiscards:      0,
					OutErrors:        0,
					PromiscuousMode:  0,
				},
				&EthernetCounter{
					AlignmentErrors: 0,
					FCSErrors:       1,
				},
			},
		},
		&FlowSample{
			SequenceNumber: 502633,
			SourceId:       2,
			SamplingRate:   2000,
			SamplePool:     1488203284,
			Drops:          3710,
			Input:          2,
			Output:         1,
			Records: []Flow{
				&SampledHeader{
					Protocol:       1,
					FrameLength:    88,
					PayloadRemoved: 4,
					Header:         []byte{0xf2, 0x29, 0x01, 0x70, 0x58, 0x25, 0x3e, 0x5b, 0x35, 0x4b, 0x3a, 0x72, 0x08, 0x00, 0x45, 0x00, 0x00, 0x46, 0xfa, 0x7c, 0x40, 0x00, 0x40, 0x06, 0x2b, 0x09, 0x0a, 0x00, 0x00, 0x96, 0x0a, 0x00, 0x00, 0x97, 0xc1, 0xec, 0x2b, 0xcb, 0x12, 0xca, 0x96, 0x0a, 0x47, 0xa6, 0x70, 0x5e, 0x80, 0x18, 0x00, 0x2e, 0x18, 0x73, 0x00, 0x00, 0x01, 0x01, 0x08, 0x0a, 0x3e, 0xd9, 0x81, 0xe9, 0x3e, 0xd9, 0x71, 0xd3, 0x67, 0x65, 0x74, 0x20, 0x73, 0x65, 0x73, 0x73, 0x69, 0x6f, 0x6e, 0x2e, 0x74, 0x69, 0x6d, 0x65, 0x0d, 0x0a},
				},
			},
		},
		&FlowSample{
			SequenceNumber: 125329,
			SourceId:       1,
			SamplingRate:   2000,
			SamplePool:     346828410,
			Drops:          1253,
			Input:          2,
			Output:         1,
			Records: []Flow{
				&SampledHeader{
					Protocol:       1,
					FrameLength:    88,
					PayloadRemoved: 4,
					Header:         []byte{0xf2, 0x29, 0x01, 0x70, 0x58, 0x25, 0x3e, 0x5b, 0x35, 0x4b, 0x3a, 0x72, 0x08, 0x00, 0x45, 0x00, 0x00, 0x46, 0xfa, 0x7c, 0x40, 0x00, 0x40, 0x06, 0x2b, 0x09, 0x0a, 0x00, 0x00, 0x96, 0x0a, 0x00, 0x00, 0x97, 0xc1, 0xec, 0x2b, 0xcb, 0x12, 0xca, 0x96, 0x0a, 0x47, 0xa6, 0x70, 0x5e, 0x80, 0x18, 0x00, 0x2e, 0x18, 0x73, 0x00, 0x00, 0x01, 0x01, 0x08, 0x0a, 0x3e, 0xd9, 0x81, 0xe9, 0x3e, 0xd9, 0x71, 0xd3, 0x67, 0x65, 0x74, 0x20, 0x73, 0x65, 0x73, 0x73, 0x69, 0x6f, 0x6e, 0x2e, 0x74, 0x69, 0x6d, 0x65, 0x0d, 0x0a},
				},
			},
		},
		&FlowSample{
			SequenceNumber: 420146,
			SourceId:       20,
			SamplingRate:   1000,
			SamplePool:     438720866,
			Drops:          374,
			Input:          22,
			Output:         20,
			Records: []Flow{
				&SampledHeader{
					Protocol:       1,
					FrameLength:    1044,
					PayloadRemoved: 4,
					Header:         []byte{0x00, 0x40, 0x10, 0x18, 0x40, 0x19, 0x00, 0x26, 0xbb, 0x52, 0x7a, 0x5e, 0x08, 0x00, 0x45, 0x00, 0x04, 0x02, 0x5b, 0x12, 0x00, 0x00, 0x40, 0x11, 0x04, 0x91, 0x0a, 0x00, 0x00, 0x46, 0x0a, 0x01, 0x03, 0x02, 0x3b, 0x5c, 0xac, 0xbc, 0x03, 0xee, 0xea, 0xac, 0xda, 0xe8, 0x1d, 0x90, 0x01, 0xbf, 0x87, 0xf0, 0xa2, 0xdd, 0xda, 0x96, 0xf0, 0x1f, 0xf7, 0x01, 0xfa, 0x15, 0x77, 0x85, 0xf4, 0x59, 0xcc, 0x82, 0xc9, 0x6f, 0x22, 0x62, 0x97, 0xb2, 0xa6, 0x3a, 0x60, 0xe3, 0xeb, 0xe4, 0x0f, 0x27, 0x1a, 0xcf, 0xfc, 0x39, 0x61, 0xcb, 0xb9, 0x19, 0x96, 0x0c, 0x2a, 0xf6, 0x80, 0x4a, 0x26, 0x96, 0xab, 0xe8, 0xae, 0x9f, 0x47, 0xba, 0x04, 0x3c, 0x68, 0x4a, 0x3a, 0x77, 0x38, 0xc6, 0xce, 0x56, 0x7b, 0x3f, 0xb2, 0x93, 0xaa, 0x3c, 0x74, 0x5e, 0x01, 0x30, 0x73, 0xa0, 0xef, 0x58, 0x35, 0xe9},
				},
			},
		},
		&FlowSample{
			SequenceNumber: 82435,
			SourceId:       3,
			SamplingRate:   2000,
			SamplePool:     195816772,
			Drops:          1613,
			Input:          2,
			Output:         3,
			Records: []Flow{
				&SampledHeader{
					Protocol:       1,
					FrameLength:    350,
					PayloadRemoved: 4,
					Header:         []byte{0x8e, 0xe6, 0xce, 0xf9, 0x57, 0x74, 0x3e, 0x5b, 0x35, 0x4b, 0x3a, 0x72, 0x08, 0x00, 0x45, 0x00, 0x01, 0x4c, 0xf7, 0x3e, 0x40, 0x00, 0x40, 0x06, 0x2d, 0x40, 0x0a, 0x00, 0x00, 0x96, 0x0a, 0x00, 0x00, 0x98, 0x00, 0x50, 0xcd, 0x08, 0x6c, 0x70, 0x76, 0xfe, 0x9f, 0x85, 0x0c, 0x28, 0x80, 0x18, 0x00, 0x36, 0x1d, 0x52, 0x00, 0x00, 0x01, 0x01, 0x08, 0x0a, 0x3e, 0xd9, 0x81, 0xe9, 0x3e, 0xd9, 0x78, 0xca, 0x48, 0x54, 0x54, 0x50, 0x2f, 0x31, 0x2e, 0x31, 0x20, 0x32, 0x30, 0x30, 0x20, 0x4f, 0x4b, 0x0d, 0x0a, 0x44, 0x61, 0x74, 0x65, 0x3a, 0x20, 0x46, 0x72, 0x69, 0x2c, 0x20, 0x32, 0x35, 0x20, 0x4a, 0x61, 0x6e, 0x20, 0x32, 0x30, 0x31, 0x33, 0x20, 0x32, 0x32, 0x3a, 0x32, 0x34, 0x3a, 0x30, 0x37, 0x20, 0x47, 0x4d, 0x54, 0x0d, 0x0a, 0x53, 0x65, 0x72, 0x76, 0x65, 0x72, 0x3a, 0x20},
				},
			},
		},
		&FlowSample{
			SequenceNumber: 363347,
			SourceId:       24,
			SamplingRate:   1000,
			SamplePool:     390849610,
			Drops:          362,
			Input:          23,
			Output:         24,
			Records: []Flow{
				&SampledHeader{
					Protocol:       1,
					FrameLength:    1114,
					PayloadRemoved: 4,
					Header:         []byte{0x00, 0x13, 0xc4, 0x55, 0x91, 0x81, 0x00, 0x40, 0x10, 0x18, 0x40, 0x19, 0x08, 0x00, 0x45, 0x00, 0x04, 0x48, 0xc0, 0xcc, 0x00, 0x00, 0xff, 0x11, 0x97, 0x71, 0xd1, 0x77, 0x23, 0x22, 0x40, 0xaf, 0x2a, 0x1e, 0x01, 0xf4, 0x01, 0xf4, 0x04, 0x34, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x74, 0x10, 0x3d, 0x54, 0x00, 0x0c, 0x75, 0xe2, 0xa8, 0x27, 0x7d, 0x1c, 0x09, 0x96, 0x28, 0xcf, 0xa2, 0xdf, 0x7d, 0x4e, 0x66, 0x27, 0xdd, 0x42, 0x29, 0xc7, 0x5e, 0x53, 0x9a, 0xd1, 0x05, 0x5f, 0x15, 0xa5, 0x80, 0x66, 0x05, 0x89, 0xa4, 0x7a, 0x7b, 0x3e, 0xee, 0x5a, 0xfc, 0xe4, 0xa8, 0x97, 0x8d, 0x46, 0x50, 0x9e, 0xda, 0x69, 0x56, 0x35, 0x9a, 0x25, 0xad, 0x62, 0xc5, 0x3e, 0xd8, 0xb0, 0xb7, 0x80, 0xc3, 0x1c, 0x25, 0xbd, 0xca, 0x40, 0x3a, 0xdd, 0x0e, 0x2c, 0xc5, 0xd9},
				},
			},
		},
	}); diff != nil {
		t.Error(diff)
	}
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
