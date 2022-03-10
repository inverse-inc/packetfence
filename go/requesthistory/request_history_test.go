package requesthistory

import (
	"context"
	"fmt"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"testing"
)

func TestNewRequestHistory(t *testing.T) {
	rh, err := NewRequestHistory(5)
	sharedutils.CheckTestError(t, err)

	if len(rh.container) != 5 {
		t.Error("Wrong size of container. Expecting 5")
	}

	rh, err = NewRequestHistory(0)

	if err == nil {
		t.Error("NewRequestHistory didn't fail when size was 0")
	}

	rh, err = NewRequestHistory(-1)

	if err == nil {
		t.Error("NewRequestHistory didn't fail when size was -1")
	}
}

func TestRequestHistoryCreate(t *testing.T) {
	size := 5
	rh, err := NewRequestHistory(size)
	sharedutils.CheckTestError(t, err)

	r, err := rh.Create("1")
	sharedutils.CheckTestError(t, err)

	if r.RequestId != "1" {
		t.Error("request ID isn't equal to the UUID that was passed")
	}

	if rh.currentPosition != 1 {
		t.Error("Create didn't increment currentPosition")
	}

	if r == nil {
		t.Error("Create didn't send a valid Request in return")
	}

	rh, err = NewRequestHistory(size)
	sharedutils.CheckTestError(t, err)

	for i := 0; i < size; i++ {
		if rh.currentPosition != i {
			t.Errorf("Wrong currentPosition at position %d", i)
		}
		r, err = rh.Create(fmt.Sprintf("%d", i))
		sharedutils.CheckTestError(t, err)
		if r != rh.container[i] {
			t.Error("Created request is not equal to the one that is in the container")
		}
	}

	if rh.currentPosition != 0 {
		t.Error("Didn't come back at the beginning when filling up request history to capacity")
	}

	r, err = rh.Create("test")
	sharedutils.CheckTestError(t, err)

	if rh.currentPosition != 1 {
		t.Error("Don't have the right currentPosition after adding an element after coming back at the beginning")
	}

	if r != rh.container[rh.UuidIndex("test")] {
		t.Error("Created request is not equal to the one in the container when coming back at the beginning")
	}

	// this should fail as test already exists
	r, err = rh.Create("test")

	if r != nil || err == nil {
		t.Error("Create didn't fail even though the UUID test is already created")
	}

}

func TestRequestHistoryGetRequestByUuid(t *testing.T) {
	rh, _ := NewRequestHistory(1)

	if _, err := rh.GetRequestByUuid("test"); err == nil {
		t.Error("No error was returned when asking for a UUID in an empty RequestHistory")
	}

	createdR, _ := rh.Create("test")
	fetchedR, _ := rh.GetRequestByUuid("test")

	if createdR != fetchedR {
		t.Error("Creating a request and fetching it after doesn't give the same request")
	}

	r, err := rh.GetRequestByUuid("poubelle")

	if r != nil || err == nil {
		t.Error("Fetching an invalid UUID didn't provide the proper error")
	}

}

func TestRequestHistoryUuidIndex(t *testing.T) {
	rh, _ := NewRequestHistory(1)

	if i := rh.UuidIndex("test"); i != -1 {
		t.Error("No error was returned when asking for a UUID in an empty RequestHistory")
	}

	_, err := rh.Create("test")
	sharedutils.CheckTestError(t, err)

	i := rh.UuidIndex("test")

	if i != 0 {
		t.Error("Creating a request and fetching it after doesn't give the right ID")
	}

	i = rh.UuidIndex("poubelle")

	if i != -1 {
		t.Error("Fetching an invalid UUID didn't provide the proper error")
	}

	_, err = rh.Create("test2")
	sharedutils.CheckTestError(t, err)

	i = rh.UuidIndex("test2")

	if i != 0 {
		t.Error("Creating a request and fetching it after doesn't give the right ID")
	}

	i = rh.UuidIndex("test")

	if i != -1 {
		t.Error("Getting an element by UUID that has been rotated still provides an index")
	}

}

func TestRequestAddMessage(t *testing.T) {
	r := NewRequest()
	if len(r.Messages) != 0 {
		t.Error("Messages aren't empty on request creation")
	}

	msg := "yes hello"
	r.AddMessage(msg)

	if len(r.Messages) != 1 {
		t.Error("Messages aren't being added in the Messages slice")
	}

	if r.Messages[0] != msg {
		t.Error("Added message isn't equal to the one that was sent in parameter")
	}
}

func TestRequestHistoryHandleLogRecord(t *testing.T) {
	rh, err := NewRequestHistory(1)
	sharedutils.CheckTestError(t, err)
	ctx := log.LoggerNewContext(context.Background())
	ctx = log.LoggerNewRequest(ctx)
	log.LoggerAddHandler(ctx, rh.HandleLogRecord)
	uuid := ctx.Value(log.RequestUuidKey).(string)

	msg := "testing"
	log.LoggerWContext(ctx).Info(msg)

	r, err := rh.GetRequestByUuid(uuid)
	sharedutils.CheckTestError(t, err)
	if r.Messages[0] != msg {
		t.Error("Log message hasn't been recorded into request UUID")
	}

	msg = "testing#2"
	log.LoggerWContext(ctx).Error(msg)
	if r.Messages[1] != msg {
		t.Error("Log message hasn't been recorded into request UUID")
	}

}

func makeRequestHistory(t *testing.T, size int, loop int) RequestHistory {
	rh, err := NewRequestHistory(size)
	sharedutils.CheckTestError(t, err)

	for i := 1; i <= loop; i++ {
		rh.Create(fmt.Sprintf("%d", i))
	}

	return rh
}

func compareWithIterator(t *testing.T, rh RequestHistory, expected []string) {
	result := rh.All()
	for i, _ := range expected {
		if expected[i] != result[i].RequestId {
			t.Errorf("Element %d isn't equal in expected and the result. Have %s instead of %s", i, expected[i], result[i].RequestId)
		}
	}
}

func TestRequestHistoryIterator(t *testing.T) {

	rh := makeRequestHistory(t, 5, 0)
	compareWithIterator(t, rh, []string{})

	rh = makeRequestHistory(t, 5, 1)
	compareWithIterator(t, rh, []string{"1"})

	rh = makeRequestHistory(t, 5, 4)
	compareWithIterator(t, rh, []string{"4", "3", "2", "1"})

	rh = makeRequestHistory(t, 5, 5)
	compareWithIterator(t, rh, []string{"5", "4", "3", "2", "1"})

	rh = makeRequestHistory(t, 5, 6)
	compareWithIterator(t, rh, []string{"6", "5", "4", "3", "2"})

	rh = makeRequestHistory(t, 5, 7)
	compareWithIterator(t, rh, []string{"7", "6", "5", "4", "3"})

	rh = makeRequestHistory(t, 5, 10)
	compareWithIterator(t, rh, []string{"10", "9", "8", "7", "6"})

}
