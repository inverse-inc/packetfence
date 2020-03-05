package main

import (
	"testing"
	"github.com/inverse-inc/packetfence/go/mac"
    "time"
)

func TestBucketAdd(t *testing.T) {
    b := NewBuckets()
    now := time.Now()
    mac, _ := mac.NewFromString("00:22:33:44:55:11")
    session := Session([16]byte{0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15})
    b.Add(1, mac, session, now, 10, 100 )
    b.Add(1, mac, session, now, 10, 100 )
    totals, _ := b.GetBucket(1, mac, session, now)
    if (totals.InBytes != 20) {
        t.Errorf("InBytes wrong total")
    }
    if (totals.OutBytes != 200) {
        t.Errorf("OutBytes wrong total")
    }

    b.Update(1, mac, session, now, 30, 300 )
    totals, _ = b.GetBucket(1, mac, session, now)
    if (totals.InBytes != 30) {
        t.Errorf("InBytes wrong total")
    }
    if (totals.OutBytes != 300) {
        t.Errorf("OutBytes wrong total")
    }

    next := now.Add(1*time.Second)

    b.Update(1, mac, session, next, 40, 400 )
    totals, _ = b.GetBucket(1, mac, session, next)
    if (totals.InBytes != 10) {
        t.Errorf("InBytes wrong total")
    }
    if (totals.OutBytes != 100) {
        t.Errorf("OutBytes wrong total")
    }

}
