package aaa

import (
	"errors"
	"fmt"
	"github.com/inverse-inc/go-utils/log"
	"time"
)

type MultiTokenBackend struct {
	backends []TokenBackend
}

func NewMultiTokenBackend(backends ...TokenBackend) TokenBackend {
	return &MultiTokenBackend{
		backends: append([]TokenBackend{}, backends...),
	}
}

func (tb *MultiTokenBackend) Type() string {
	return "multi"
}

func (tb *MultiTokenBackend) TokenInfoForToken(token string) (*TokenInfo, time.Time) {
	for _, b := range tb.backends {
		token, t := b.TokenInfoForToken(token)
		if token != nil {
			return token, t
		}
	}

	return nil, time.Unix(0, 0)
}

func (tb *MultiTokenBackend) StoreTokenInfo(token string, ti *TokenInfo) error {
	var errs []error
	for _, b := range tb.backends {
		err := b.StoreTokenInfo(token, ti)
		if err != nil {
			errs = append(errs, err)
			log.Logger().Warn(fmt.Sprintf("Unable to store in a backend %s: %s", b.Type(), err.Error()))
		}
	}

	if len(errs) == len(tb.backends) {
		return errors.New("No store available")
	}

	return nil
}

func (tb *MultiTokenBackend) TokenIsValid(token string) bool {
	for _, b := range tb.backends {
		if b.TokenIsValid(token) {
			return true
		}
	}

	return false
}

func (tb *MultiTokenBackend) TouchTokenInfo(token string) {
	for _, b := range tb.backends {
		b.TokenIsValid(token)
	}
}

func (tb *MultiTokenBackend) AdminActionsForToken(token string) map[string]bool {
	for _, b := range tb.backends {
		if ti, _ := b.TokenInfoForToken(token); ti != nil {
			return ti.AdminActions()
		}
	}

	return make(map[string]bool)
}

var _ TokenBackend = (*MultiTokenBackend)(nil)
