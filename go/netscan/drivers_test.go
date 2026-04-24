package netscan

import (
	"encoding/json"
	"testing"
)

func TestDriversJSONIsValid(t *testing.T) {
	if len(driversJSON) == 0 {
		t.Fatal("embedded drivers.json is empty")
	}
	if !json.Valid(driversJSON) {
		t.Fatal("embedded drivers.json is not valid JSON")
	}
	d, err := loadDrivers()
	if err != nil {
		t.Fatalf("loadDrivers failed: %v", err)
	}
	if len(d.Devices) == 0 {
		t.Fatal("embedded drivers.json contains no devices")
	}
}
