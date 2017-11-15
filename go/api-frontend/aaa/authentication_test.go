package aaa

import (
	"context"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/log"
)

func TestTokenAuthenticationMiddlewareIsAuthenticated(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())

	backend := NewMemTokenBackend(1 * time.Second)
	tam := NewTokenAuthenticationMiddleware(backend)
	token := "t-to-the-o-to-the-ken"

	// Test non-existant token
	res, _ := tam.IsAuthenticated(ctx, token)

	if res {
		t.Error("Invalid token was seen as authenticated")
	}

	// Test valid token
	backend.StoreTokenInfo(token, &TokenInfo{})

	res, _ = tam.IsAuthenticated(ctx, token)

	if !res {
		t.Error("Valid token wasn't seen as authenticated")
	}

	// Test expired token
	time.Sleep(1 * time.Second)

	res, _ = tam.IsAuthenticated(ctx, token)

	if res {
		t.Error("Expired token is still seen as valid")
	}

}
