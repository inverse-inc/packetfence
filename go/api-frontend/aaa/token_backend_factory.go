package aaa

import (
	"time"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

var factories = map[string]func(expiration time.Duration, maxExpiration time.Duration, args []string) TokenBackend{
	"db":    NewDbTokenBackend,
	"mem":   NewMemTokenBackend,
	"redis": NewRedisTokenBackend,
}

func MakeTokenBackend(args []string) TokenBackend {
	timeout := time.Duration(pfconfigdriver.Config.PfConf.Advanced.ApiInactivityTimeout) * time.Second
	expiration := time.Duration(pfconfigdriver.Config.PfConf.Advanced.ApiMaxExpiration) * time.Second
	if len(args) == 0 {
		return NewMemTokenBackend(
			timeout,
			expiration,
			args,
		)
	}

	backends := []TokenBackend{}
	for _, t := range args {
		factory, found := factories[t]
		if !found {
			continue
		}

		backends = append(backends, factory(timeout, expiration, nil))
	}

	if len(backends) == 1 {
		return backends[0]
	}

	return NewMultiTokenBackend(backends...)

}
