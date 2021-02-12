package panichandler

import (
	"context"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"testing"
)

var ctx = context.Background()

func TestHttp(t *testing.T) {
	defer func() {
		if r := recover(); r != nil {
			t.Error("Had to recover a panic in the emergency handler while the normal handlers should have caught it...")
		}
	}()

	w := httptest.NewRecorder()
	func() {
		defer Http(ctx, w)
		panic("I'm a valid panic that should be caught by the Http panic handler")
	}()

	resp, err := ioutil.ReadAll(w.Body)
	sharedutils.CheckTestError(t, err)

	if string(resp) != httpErrorMsg+"\n" {
		t.Errorf("Error message isn't valid in Http panic handler. Got %s instead of %s", resp, httpErrorMsg)
	}

	if w.Code != http.StatusInternalServerError {
		t.Errorf("Response code is invalid when Http recovers a panic. Should give %d but gave %d", http.StatusInternalServerError, w.Code)
	}

}

func TestStandard(t *testing.T) {
	defer func() {
		if r := recover(); r != nil {
			t.Error("Had to recover a panic in the emergency handler while the normal handlers should have caught it...")
		}
	}()

	func() {
		defer Standard(ctx)
		panic("I'm a valid panic that should be caught by the Http panic handler")
	}()

}
