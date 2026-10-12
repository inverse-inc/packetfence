package models_test

import (
	"testing"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
)

// Secrets can't be used to filter or sort a search.
func TestSecretsNotSearchable(t *testing.T) {
	for _, c := range []struct {
		class   interface{}
		secrets []string
	}{
		{models.HSM{}, []string{"pin"}},
		{models.Profile{}, []string{"est_password", "scep_challenge_password"}},
		{models.SCEPServer{}, []string{"shared_secret"}},
	} {
		for _, field := range c.secrets {
			if _, err := (sql.Search{Field: field, Op: "starts_with", Value: "a"}).SqlWhere(c.class); err == nil {
				t.Errorf("%T: %s is searchable", c.class, field)
			}
		}
	}
}
