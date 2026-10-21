package utils_test

import (
	"slices"
	"testing"
)

func IsEqStr(t *testing.T, extra_log string, actual, expected string) {
	if expected != actual {
		if len(extra_log) == 0 {
			t.Fatalf("Expected '%s', got '%s'", expected, actual)
		} else {
			t.Fatalf("[%s] Expected '%s', got '%s'", extra_log, expected, actual)
		}
	}
}

func IsEqInt(t *testing.T, extra_log string, actual, expected int) {
	if expected != actual {
		if len(extra_log) == 0 {
			t.Fatalf("Expected %d, got %d", expected, actual)
		} else {
			t.Fatalf("[%s] Expected %d, got %d", extra_log, expected, actual)
		}
	}
}

func IsEqBool(t *testing.T, extra_log string, actual, expected bool) {
	if expected != actual {
		if len(extra_log) == 0 {
			t.Fatalf("Expected %t, got %t", expected, actual)
		} else {
			t.Fatalf("[%s] Expected %t, got %t", extra_log, expected, actual)
		}
	}
}

func IsGT(t *testing.T, extra_log string, actual, expected int) {
	if actual <= expected {
		if len(extra_log) == 0 {
			t.Fatalf("Expected >%d, got %d", expected, actual)
		} else {
			t.Fatalf("[%s] Expected >%d, got %d", extra_log, expected, actual)
		}
	}
}

func IsGTE(t *testing.T, extra_log string, actual, expected int) {
	if actual < expected {
		if len(extra_log) == 0 {
			t.Fatalf("Expected >=%d, got %d", expected, actual)
		} else {
			t.Fatalf("[%s] Expected >=%d, got %d", extra_log, expected, actual)
		}
	}
}

func IsLT(t *testing.T, extra_log string, actual, expected int) {
	if actual >= expected {
		if len(extra_log) == 0 {
			t.Fatalf("Expected <%d, got %d", expected, actual)
		} else {
			t.Fatalf("[%s] Expected <%d, got %d", extra_log, expected, actual)
		}
	}
}

func IsLTE(t *testing.T, extra_log string, actual, expected int) {
	if actual > expected {
		if len(extra_log) == 0 {
			t.Fatalf("Expected <=%d, got %d", expected, actual)
		} else {
			t.Fatalf("[%s] Expected <=%d, got %d", extra_log, expected, actual)
		}
	}
}

func IsEqArr(t *testing.T, extra_log string, actual, expected []any) {
	if !slices.Equal(actual, expected) {
		if len(extra_log) == 0 {
			t.Fatalf("Array not equal: %v => %v", expected, actual)
		} else {
			t.Fatalf("[%s] Array not equal: %v => %v", extra_log, expected, actual)
		}
	}
}

func IsNil(t *testing.T, extra_log string, actual any) {
	if actual != nil {
		if len(extra_log) == 0 {
			t.Fatalf("Expected nil value")
		} else {
			t.Fatalf("[%s] Expected nil value", extra_log)
		}
	}
}
