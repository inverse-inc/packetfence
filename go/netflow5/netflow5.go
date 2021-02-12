package netflow5

// NetFlow5 Represents the in memory layout of a NetFlow v5 packet
type NetFlow5 struct {
	Header Header
	Flows  [30]Flow
}

func (f *NetFlow5) FlowArray() []Flow {
	return f.Flows[:f.Header.Length()]
}
