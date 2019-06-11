package netflow5

type Header struct {
	nVersion          uint16
	nLength           uint16
	nSysUptime        uint32
	nUnixSecs         uint32
	nUnixNsecs        uint32
	nFlowSequence     uint32
	EngineType        uint8
	EngineId          uint8
	nSamplingInterval uint16
}

func (h *Header) Version() uint16          { return Ntoh16(h.nVersion) }
func (h *Header) Length() uint16           { return Ntoh16(h.nLength) }
func (h *Header) SamplingInterval() uint16 { return Ntoh16(h.nSamplingInterval) }
func (h *Header) SysUptime() uint32        { return Ntoh32(h.nSysUptime) }
func (h *Header) UnixSecs() uint32         { return Ntoh32(h.nUnixSecs) }
func (h *Header) UnixNsecs() uint32        { return Ntoh32(h.nUnixNsecs) }
func (h *Header) FlowSequence() uint32     { return Ntoh32(h.nFlowSequence) }
