package aaa

import (
	"context"
	"errors"
	"net/http"
	"strings"

	"github.com/satori/go.uuid"
)

type TokenAuthenticationMiddleware struct {
	tokenBackend TokenBackend
	authBackends []AuthenticationBackend
}

func NewTokenAuthenticationMiddleware(tb TokenBackend) *TokenAuthenticationMiddleware {
	return &TokenAuthenticationMiddleware{
		tokenBackend: tb,
		authBackends: []AuthenticationBackend{},
	}
}

func (tam *TokenAuthenticationMiddleware) AddAuthenticationBackend(ab AuthenticationBackend) {
	tam.authBackends = append(tam.authBackends, ab)
}

func (tam *TokenAuthenticationMiddleware) Login(ctx context.Context, username, password string) (bool, string, error) {
	for _, backend := range tam.authBackends {
		if auth, tokenInfo, _ := backend.Authenticate(ctx, username, password); auth {
			token := uuid.NewV4().String()
			tam.tokenBackend.StoreTokenInfo(token, tokenInfo)
			return true, token, nil
		}
	}
	return false, "", errors.New("Wasn't able to authenticate those credentials")
}

func (tam *TokenAuthenticationMiddleware) BearerRequestIsAuthorized(ctx context.Context, r *http.Request) (bool, error) {
	authHeader := r.Header.Get("Authorization")
	token := strings.TrimPrefix(authHeader, "Bearer ")
	return tam.IsAuthenticated(ctx, token)
}

func (tam *TokenAuthenticationMiddleware) IsAuthenticated(ctx context.Context, token string) (bool, error) {
	return tam.tokenBackend.TokenIsValid(token), nil
}
