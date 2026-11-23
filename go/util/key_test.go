package util

import "testing"

func TestLengthPrefixedKey(t *testing.T) {
	for _, test := range []struct {
		parts []string
		want  string
	}{
		{nil, ""},
		{[]string{""}, "0:"},
		{[]string{"a"}, "1:a"},
		{[]string{"ab", "", "c"}, "2:ab0:1:c"},
		{[]string{"a|b", "1:x"}, "3:a|b3:1:x"},
		{[]string{"é"}, "2:é"},
	} {
		if got := LengthPrefixedKey(test.parts...); got != test.want {
			t.Errorf("LengthPrefixedKey(%q) = %q, want %q", test.parts, got, test.want)
		}
	}
}

func TestLengthPrefixedKeyNoCollisions(t *testing.T) {
	// Each pair has the same concatenation but different parts.
	for _, test := range [][2][]string{
		{{"a", "false|example.com."}, {"a|false", "example.com."}},
		{{"ab", "c"}, {"a", "bc"}},
		{{"1:a", ""}, {"", "1:a"}},
		{{"", "a"}, {"a"}},
		{{"3:abc"}, {"3:", "abc"}},
		{{"", ""}, {""}},
	} {
		if a, b := LengthPrefixedKey(test[0]...), LengthPrefixedKey(test[1]...); a == b {
			t.Errorf("LengthPrefixedKey(%q) and LengthPrefixedKey(%q) are both %q", test[0], test[1], a)
		}
	}
}
