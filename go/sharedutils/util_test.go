package sharedutils

import (
	"net/http"
	"testing"
)

func TestTupleToMap(t *testing.T) {
	result, err := TupleToMap([]interface{}{"test1", "test2", "test3", "test4"})
	CheckTestError(t, err)

	expected := map[interface{}]interface{}{"test1": "test2", "test3": "test4"}

	for k, v := range expected {
		if resultV, ok := result[k]; ok {
			if resultV != v {
				t.Errorf("Value is not correct for key %s", k)
			}
		} else {
			t.Errorf("Key %s not found in result", k)
		}
	}

	result, err = TupleToMap([]interface{}{"test1", "test2", "test3"})

	if result != nil || err == nil {
		t.Error("Expected nil and error when sending odd numbers of element to TupleToMap")
	}
}

func TestTupleToOrderedMap(t *testing.T) {
	result, err := TupleToOrderedMap([]interface{}{"test1", "test2", "test3", "test4"})
	CheckTestError(t, err)

	expected := map[interface{}]interface{}{"test1": "test2", "test3": "test4"}

	for k, v := range expected {
		if resultV, ok := result.Get(k); ok {
			if resultV != v {
				t.Errorf("Value is not correct for key %s", k)
			}
		} else {
			t.Errorf("Key %s not found in result", k)
		}
	}

	result, err = TupleToOrderedMap([]interface{}{"test1", "test2", "test3"})

	if result != nil || err == nil {
		t.Error("Expected nil and error when sending odd numbers of element to TupleToMap")
	}
}

func TestRandomBytes(t *testing.T) {
	length := uint64(1024)
	rd := RandomBytes(length)

	// There is 1 / 255^1024 chance they'll all be zeros
	// If this test fails one day, make sure you go buy a loto ticket
	allZeros := true
	for _, b := range rd {
		if b != 0 {
			allZeros = false
		}
	}

	if allZeros {
		t.Error("RandomBytes didn't generate any random bytes")
	}
}

func TestAllEquals(t *testing.T) {
	if !AllEquals(1, 1, 1, 1) {
		t.Error("AllEquals didn't detect equality correctly")
	}
	if AllEquals(1, 1, 1, 2) {
		t.Error("AllEquals didn't detect equality correctly")
	}
	if AllEquals(2, 1, 1, 1) {
		t.Error("AllEquals didn't detect equality correctly")
	}
	if AllEquals(1, 2, 3, 4) {
		t.Error("AllEquals didn't detect equality correctly")
	}
}

func TestCopyHttpRequest(t *testing.T) {
	req, err := http.NewRequest("GET", "http://test.com/test", nil)
	CheckError(err)
	req.Header.Add("X-Test-1", "test-1")

	newReq, err := CopyHttpRequest(req)

	if err != nil {
		t.Error("Copying a valid HTTP request failed")
	}

	if newReq.Header.Get("X-Test-1") != "test-1" {
		t.Error("Failed to get a header in the copied request")
	}

	req.Header.Add("X-Test-2", "test-2")

	if newReq.Header.Get("X-Test-2") != "" {
		t.Error("Header was set on copy after the request was copied")
	}

}
