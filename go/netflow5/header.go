package netflow5

type Header struct {
	nVersion          uint16
	nLength           uint16
	nSysUptime        uint32
	nUnixSecs         uint32
	nUnixNsecs        uint32
	nFlowSequence     uint32
    // EngineType Type of flow-switching engine
	EngineType        uint8
    // EngineId Slot number of the flow-switching engine
	EngineId          uint8
	nSamplingInterval uint16
}

// Version NetFlow export format version number.
func (h *Header) Version() uint16          { return ntoh16(h.nVersion) }
// Length Number of flows exported in this packet (1-30).
func (h *Header) Length() uint16           { return ntoh16(h.nLength) }
// SamplingInterval First two bits hold the sampling mode; remaining 14 bits hold value of sampling interval
func (h *Header) SamplingInterval() uint16 { return ntoh16(h.nSamplingInterval) }
// SysUptime Current time in milliseconds since the export device booted
func (h *Header) SysUptime() uint32        { return ntoh32(h.nSysUptime) }
// UnixSecs Current count of seconds since 0000 UTC 1970
func (h *Header) UnixSecs() uint32         { return ntoh32(h.nUnixSecs) }
// UnixNsecs Residual nanoseconds since 0000 UTC 1970
func (h *Header) UnixNsecs() uint32        { return ntoh32(h.nUnixNsecs) }
// FlowSequence Sequence counter of total flows seen
func (h *Header) FlowSequence() uint32     { return ntoh32(h.nFlowSequence) }
