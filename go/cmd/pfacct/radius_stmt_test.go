package main

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/inverse-inc/go-radius/rfc2866"
	"github.com/inverse-inc/go-utils/mac"
	"github.com/inverse-inc/packetfence/go/db"
)

func TestOnOffOnlne(t *testing.T) {
	var ctx = context.Background()
	db, err := db.DbFromConfig(ctx)
	if err != nil {
		t.Fatalf("DB Error:%s", err.Error())
	}
	mac, _ := mac.NewFromString("00:22:22:44:44:55")
	db.Exec("delete from node_current_session where mac = ?", mac.String())
	rs := RadiusStatements{}
	rs.Setup(db)
	rs.updateNodeOnlineOfflineOnline(
		rfc2866.AcctStatusType_Value_Start,
		mac,
		1,
	)

	online := 0
	updated := time.Time{}
	row := db.QueryRow("select is_online, updated from node_current_session where mac = ?", mac.String())
	err = row.Scan(&online, &updated)
	if err != nil {
		t.Fatalf("Scan error: %s", err.Error())
	}

	if online == 0 {
		t.Fatalf("node %s is not online", mac.String())
	}

	fmt.Printf("updated:%s\n", updated.String())
	time.Sleep(1 * time.Second)

	rs.updateNodeOnlineOfflineOnline(
		rfc2866.AcctStatusType_Value_Stop,
		mac,
		1,
	)
	updated2 := time.Time{}

	row = db.QueryRow("select is_online, updated from node_current_session where mac = ?", mac.String())
	err = row.Scan(&online, &updated2)
	if err != nil {
		t.Fatalf("Scan error: %s", err.Error())
	}

	if updated.Equal(updated2) {
		t.Fatalf("%s updated does not work\n", mac.String())
	}

	if online != 0 {
		t.Fatalf("node %s is online", mac.String())
	}

	fmt.Printf("updated:%s\n", updated2.String())
	time.Sleep(1 * time.Second)

	updated3 := time.Time{}
	rs.updateNodeOnlineOfflineOnline(
		rfc2866.AcctStatusType_Value_Start,
		mac,
		1,
	)
	row = db.QueryRow("select is_online, updated from node_current_session where mac = ?", mac.String())
	err = row.Scan(&online, &updated3)
	if err != nil {
		t.Fatalf("Scan error: %s", err.Error())
	}

	if updated2.Equal(updated3) {
		t.Fatalf("%s updated does not work\n", mac.String())
	}

	fmt.Printf("updated:%s\n", updated3.String())

	if online == 0 {
		t.Fatalf("node %s is not online", mac.String())
	}

}
