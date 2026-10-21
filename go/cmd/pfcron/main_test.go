package main

import (
	"net"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"
)

func TestUpdateProcessingReportsSchedulerState(t *testing.T) {
	previous := atomic.LoadUint32(&processJobs)
	t.Cleanup(func() { atomic.StoreUint32(&processJobs, previous) })
	socket := filepath.Join(t.TempDir(), "notify.sock")
	conn, err := net.ListenUnixgram("unixgram", &net.UnixAddr{Name: socket, Net: "unixgram"})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { conn.Close() })
	t.Setenv("NOTIFY_SOCKET", socket)

	// Follow both failover and failback, including repeated role refreshes.
	for _, master := range []bool{false, true, true, false, false, true} {
		updateProcessing(master)
		wantState := uint32(0)
		wantStatus := "STATUS=Not processing non-local jobs"
		if master {
			wantState = 1
			wantStatus = "STATUS=Processing non-local jobs"
		}
		if got := atomic.LoadUint32(&processJobs); got != wantState {
			t.Fatalf("master=%t: scheduler gate=%d, want %d", master, got, wantState)
		}
		if err := conn.SetReadDeadline(time.Now().Add(time.Second)); err != nil {
			t.Fatal(err)
		}
		buf := make([]byte, 256)
		n, _, err := conn.ReadFromUnix(buf)
		if err != nil {
			t.Fatal(err)
		}
		if got := string(buf[:n]); got != wantStatus {
			t.Fatalf("master=%t: status=%q, want %q", master, got, wantStatus)
		}
	}
}
