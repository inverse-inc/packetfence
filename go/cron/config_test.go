package maint

import (
	"errors"
	"testing"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func TestMaintenanceTasks(t *testing.T) {
	tasks := map[string]interface{}{
		"flush_radius_audit_log": map[string]interface{}{"status": "enabled"},
	}

	tests := []struct {
		name    string
		in      pfconfigdriver.PfconfigObject
		wantErr bool
	}{
		{name: "no object", in: nil, wantErr: true},
		{name: "nil Cron", in: (*pfconfigdriver.Cron)(nil), wantErr: true},
		// What an empty reply of pfconfig decodes to
		{name: "Cron without element", in: &pfconfigdriver.Cron{}, wantErr: true},
		{name: "Cron with an empty element", in: &pfconfigdriver.Cron{Element: map[string]interface{}{}}, wantErr: true},
		{name: "another pfconfig object", in: &pfconfigdriver.ManagementNetwork{}, wantErr: true},
		{name: "Cron with tasks", in: &pfconfigdriver.Cron{Element: tasks}, wantErr: false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := maintenanceTasks(tt.in)
			if tt.wantErr {
				if !errors.Is(err, ErrNoMaintenanceTasks) {
					t.Fatalf("expected ErrNoMaintenanceTasks, got %v", err)
				}
				if got != nil {
					t.Fatalf("expected no task, got %v", got)
				}
				return
			}

			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if _, found := got["flush_radius_audit_log"]; !found {
				t.Fatalf("expected the tasks of the Cron object, got %v", got)
			}
		})
	}
}
