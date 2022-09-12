package api

import (
	"bytes"
	"encoding/json"
	"io/ioutil"
	"net/http/httptest"
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

	query = &Query{
		Op: "or",
		Values: []Query{
			Query{Field: "name", Op: "equals", Value: "User-Name"},
			Query{Field: "name", Op: "equals", Value: "User-Password"},
		},
	}

	if f, err = makeRadiusAttributeFilter(query); err != nil {
		t.Error(err)
	} else {
		l = radisAttributesFilter(radiusAttributes, f)
		for _, a := range l {
			if a.Name != "User-Name" && a.Name != "User-Password" {
				t.Errorf("%s does not 'User-Name' or 'User-Password'", a.Name)
			}
		}
	}

	query = &Query{
		Op: "and",
		Values: []Query{
			Query{Field: "name", Op: "starts_with", Value: "User"},
			Query{Field: "name", Op: "ends_with", Value: "Password"},
		},
	}

	if f, err = makeRadiusAttributeFilter(query); err != nil {
		t.Error(err)
	} else {
		l = radisAttributesFilter(radiusAttributes, f)
		for _, a := range l {
			if !strings.HasPrefix(a.Name, "User") || !strings.HasSuffix(a.Name, "Password") {
				t.Errorf("%s does not starts 'User' and ends_with 'Password'", a.Name)
			}
		}
	}

}

func doSearch(body string) *httptest.ResponseRecorder {
	h := APIHandler{}
	req := httptest.NewRequest(
		"POST",
		"/api/v1/radius_attributes",
		bytes.NewBufferString(body),
	)
	w := httptest.NewRecorder()
	h.searchRadiusAttributes(w, req, nil)
	return w
}

func TestHttpRequest(t *testing.T) {
	w := doSearch(`{"query":{"op":"equals", "field": "name", "value": "User-Name" }}`)
	resp := w.Result()
	body, _ := ioutil.ReadAll(resp.Body)
	searchResults := RadiusAttributesResults{}
	json.Unmarshal(body, &searchResults)
	if len(searchResults.Items) == 0 {
		t.Errorf("Result count is incorrect got %d instead of 1", len(searchResults.Items))
	} else {
		for _, i := range searchResults.Items {
			if i.Name != "User-Name" {
				t.Errorf("Got %s instead of 'User-Name'", i.Name)
			}
		}
	}

	w = doSearch(`{}`)
	resp = w.Result()
	body, _ = ioutil.ReadAll(resp.Body)
	searchResults = RadiusAttributesResults{}
	json.Unmarshal(body, &searchResults)
	if len(searchResults.Items) != len(radiusAttributes) {
		t.Errorf("Result count is incorrect got %d instead of %d", len(searchResults.Items), len(radiusAttributes))
	}

	w = doSearch(`{"query":{"op":"equals", "field": "nme", "value": "User-Name" }}`)
	resp = w.Result()
	body, _ = ioutil.ReadAll(resp.Body)
	searchResults = RadiusAttributesResults{}
	json.Unmarshal(body, &searchResults)
	if len(searchResults.Items) != 0 {
		t.Errorf("Result count is incorrect got %d instead of %d", len(searchResults.Items), 0)
	} else if searchResults.Status != 422 {
		t.Errorf("Status is incorrect got %d instead of %d", searchResults.Status, 422)
	}
}
