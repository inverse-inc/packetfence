package aaa

import (
	"context"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/log"
)

func TestTokenAuthenticationMiddlewareIsAuthenticated(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())

	backend := NewMemTokenBackend(1*time.Second, 1*time.Second)
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

func TestTokenAuthenticationMiddlewareLogin(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())

	backend := NewMemTokenBackend(1*time.Second, 1*time.Second)
	tam := NewTokenAuthenticationMiddleware(backend)

	tam.AddAuthenticationBackend(NewMemAuthenticationBackend(
		map[string]string{
			"bob": "garauge",
		},
		map[string]bool{
			"ALL": true,
		},
	))

	// valid login
	auth, token, err := tam.Login(ctx, "bob", "garauge")

	if !auth {
		t.Error("Valid auth didn't pass login")
	}

	if token == "" {
		t.Error("Valid auth returned empty token")
	}

	if err != nil {
		t.Error("Valid auth returned error")
	}

	// invalid login
	auth, token, err = tam.Login(ctx, "bob", "badpwd")

	if auth {
		t.Error("Invalid auth succeeded")
	}

	if token != "" {
		t.Error("Invalid auth returned a token")
	}

	if err == nil {
		t.Error("Invalid auth didn't return an error")
	}

}
