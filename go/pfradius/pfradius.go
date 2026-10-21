// Package pfradius holds constants for PacketFence's RADIUS vendor dictionary
// that are shared across binaries (pfacct, pfconnector, ...) so the values
// cannot drift between independent copies.
//
// It is intentionally a zero-dependency leaf package: it must stay importable
// from anywhere (including packages with their own dictionary-loading init())
// without pulling in side effects.
package pfradius

// The constants are deliberately untyped so they adapt to both the uint32
// vendor-id context and the byte attribute-type context at their call sites.
const (
	// VendorID is the PacketFence RADIUS vendor id (dictionary.packetfence,
	// "Vendor-Id 29464").
	VendorID = 29464

	// ConnectorIDAttrType is the vendor attribute number of the
	// PacketFence-ConnectorID VSA, used to identify traffic that arrived via a
	// pfconnector tunnel.
	ConnectorIDAttrType = 40
)
