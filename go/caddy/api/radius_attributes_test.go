package api

import (
	"strings"
	"testing"
)

func TestFiltering(t *testing.T) {
	setupRadiusDictionary()
	firstLen := len(radiusAttributes)
	l := radisAttributesFilter(radiusAttributes, radisAttributesFilterTrue)
	newLen := len(l)
	if firstLen != newLen {
		t.Errorf("Expected %d got %d", firstLen, newLen)
	}

	l = radisAttributesFilter(radiusAttributes, radisAttributesFilterFalse)
	newLen = len(l)
	if newLen != 0 {
		t.Errorf("Expected %d got %d", 0, newLen)
	}

	query := &Query{Field: "name", Op: "contains", Value: "Realm"}

	f, err := makeRadiusAttributeFilter(query)
	if err != nil {
		t.Error(err)
	}

	l = radisAttributesFilter(radiusAttributes, f)

	for _, a := range l {
		if !strings.Contains(a.Name, "Realm") {
			t.Errorf("%s does not contain 'Realm'", a.Name)
		}
	}
}
