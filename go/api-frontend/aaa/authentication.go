package aaa

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/inverse-inc/go-utils/log"
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

func (tam *TokenAuthenticationMiddleware) GenerateToken() (string, error) {
	tokenLength := 32
	b := make([]byte, tokenLength)
	l, err := rand.Read(b)

	if l != tokenLength {
		return "", errors.New("Didn't generate a token of the right length")
	} else if err != nil {
		return "", err
	} else {
		tokenBytes := make([]byte, hex.EncodedLen(len(b)))
		hex.Encode(tokenBytes, b)

		return string(tokenBytes), nil
	}
}

func (tam *TokenAuthenticationMiddleware) Login(ctx context.Context, username, password string) (bool, string, error) {
	for _, backend := range tam.authBackends {
		if auth, tokenInfo, err := backend.Authenticate(ctx, username, password); auth {
			log.LoggerWContext(ctx).Info(fmt.Sprintf("API login for user %s", username))
			token, err := tam.GenerateToken()
			if err != nil {
				return false, "", err
			}

			// Don't set it if it was set by the backend
			if tokenInfo.Username == "" {
				tokenInfo.Username = username
			}

			tam.tokenBackend.StoreTokenInfo(token, tokenInfo)
			return true, token, nil
		} else if err != nil {
			log.LoggerWContext(ctx).Error(fmt.Sprintf("Error while authenticating user %s: %s", username, err))
		}
	}
	return false, "", errors.New("Wasn't able to authenticate those credentials")
}

func (tam *TokenAuthenticationMiddleware) BearerRequestIsAuthorized(ctx context.Context, r *http.Request) (bool, error) {
	token := tam.tokenFromRequest(ctx, r)
	return tam.IsAuthenticated(ctx, token)
}

func (tam *TokenAuthenticationMiddleware) tokenFromRequest(ctx context.Context, r *http.Request) string {
	authHeader := r.Header.Get("Authorization")
	return strings.TrimPrefix(authHeader, "Bearer ")
}

func (tam *TokenAuthenticationMiddleware) IsAuthenticated(ctx context.Context, token string) (bool, error) {
	return tam.tokenBackend.TokenIsValid(token), nil
}

func (tam *TokenAuthenticationMiddleware) TouchTokenInfo(ctx context.Context, r *http.Request) {
	tam.tokenBackend.TouchTokenInfo(tam.tokenFromRequest(ctx, r))
}

func (tam *TokenAuthenticationMiddleware) ExtractUserIdentity(r *http.Request) (string, string, bool) {
	auth := r.Header.Get("Authorization")
	if auth == "" {
		return "", "", false
	}

	parts := strings.SplitN(auth, " ", 2)
	if len(parts) != 2 || strings.ToUpper(parts[0]) != strings.ToUpper("Basic") {
		return "", "", false
	}

	payload, err := base64.StdEncoding.DecodeString(parts[1])
	if err != nil {
		return "", "", false
	}

	pair := strings.SplitN(string(payload), ":", 2)
	if len(pair) != 2 {
		return "", "", false
	}

	return pair[0], pair[1], true
}
