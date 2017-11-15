package aaa

import (
	"context"
	"net/http"
	"strings"
)

type TokenAuthenticationMiddleware struct {
	tokenBackend TokenBackend
}

func NewTokenAuthenticationMiddleware(tb TokenBackend) *TokenAuthenticationMiddleware {
	return &TokenAuthenticationMiddleware{
		tokenBackend: tb,
	}
}

func (tam *TokenAuthenticationMiddleware) BearerRequestIsAuthorized(ctx context.Context, r *http.Request) (bool, error) {
	authHeader := r.Header.Get("Authorization")
	token := strings.TrimPrefix(authHeader, "Bearer ")
	return tam.IsAuthenticated(ctx, token)
}

func (tam *TokenAuthenticationMiddleware) IsAuthenticated(ctx context.Context, token string) (bool, error) {
	return tam.tokenBackend.TokenIsValid(token), nil
}
