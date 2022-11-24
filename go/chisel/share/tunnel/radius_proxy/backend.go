package radius_proxy

type RadiusBackend struct {
	addr string
}

func NewRadiusBackend(addr string) *RadiusBackend {
	be := &RadiusBackend{
		addr: addr,
	}

	return be
}
