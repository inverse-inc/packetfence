package models_test

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/cloud"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
)

// queueCloud is a provider whose revocation queue holds serials, or
// fails to download.
type queueCloud struct {
	validatedCloud
	serials []string
	err     error
}

func (q queueCloud) ProcessRevocations(ctx context.Context, caName string, revoke cloud.RevokeFunc) (int, error) {
	if q.err != nil {
		return 0, q.err
	}
	for i, s := range q.serials {
		revoke(ctx, cloud.RevocationRequest{RequestID: string(rune('a' + i)), SerialNumber: s})
	}
	return len(q.serials), nil
}

// The run fails when the queue of a profile couldn't be processed, but
// the other profiles are still processed.
func TestProcessCloudRevocations_ReportsFailures(t *testing.T) {
	env := testutil.NewEnv(t)
	okCA, okProf := newTestProfile(t, env, "cloud-ok")
	_, badProf := newTestProfile(t, env, "cloud-bad")
	for _, p := range []models.Profile{okProf, badProf} {
		env.DB.Model(&p).Updates(map[string]interface{}{"cloud_enabled": 1, "cloud_service": p.Name})
	}
	insertCertRow(t, env, okCA, okProf, "dev", "5")

	queues := map[string]queueCloud{
		"cloud-ok":  {serials: []string{"5"}},
		"cloud-bad": {err: errors.New("intune unreachable")},
	}
	defer models.SetCloudCreate(func(_ context.Context, _, name string) (cloud.Cloud, error) {
		return queues[name], nil
	})()

	run := models.Cert{DB: env.DB, Ctx: env.Ctx}
	info, err := run.ProcessCloudRevocations()
	if err == nil || !strings.Contains(err.Error(), "cloud-bad") || strings.Contains(err.Error(), "cloud-ok") {
		t.Fatalf("err = %v, want the cloud-bad failure", err)
	}
	if info.TotalCount != 1 {
		t.Errorf("TotalCount = %d, want 1", info.TotalCount)
	}

	queues["cloud-bad"] = queueCloud{}
	if _, err := run.ProcessCloudRevocations(); err != nil {
		t.Errorf("err = %v once every queue is processed", err)
	}
}
