package sharedutils

import (
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
