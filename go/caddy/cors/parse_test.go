package caddy

import (
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"reflect"
	"testing"
)

func TestParse_OneLines(t *testing.T) {
	type testCase struct {
		desc           string
		text           string
		numRules       int
		path           string
		allowedOrigins []string
		errors         bool
	}
	testCases := []testCase{
		{"Plain", "cors", 1, "/", []string{"*"}, false},
		{"Single arg path", "cors /foo", 1, "/foo", []string{"*"}, false},
		{"Additional arg domain", "cors /foo http://foo.com", 1, "/foo", []string{"http://foo.com"}, false},
		{"Multiple domains", "cors /foo http://foo.com,http://bar.com", 1, "/foo", []string{"http://foo.com", "http://bar.com"}, false},
		{"Extra args", "cors /foo http://foo.com http://bar.com", 1, "/foo", []string{"http://foo.com", "http://bar.com"}, true},
	}
	for _, test := range testCases {
		c := caddy.NewTestController("http", test.text)
		rules, err := parseRules(c)
		if err != nil {
			if test.errors {
				continue
			}
			t.Fatal(test.desc, err)
		}
		if len(rules) != test.numRules {
			t.Fatalf("%s: Expected %d rules, but found %d.", test.desc, test.numRules, len(rules))
		}
		if rules[0].Path != test.path {
			t.Fatalf("%s: Expected path of %s, but found %s.", test.desc, test.path, rules[0].Path)
		}
		if !reflect.DeepEqual(rules[0].Conf.AllowedOrigins, test.allowedOrigins) {
			t.Fatalf("%s: Allowed origins don't match. Expected: %v. Actual: %v.", test.desc, test.allowedOrigins, rules[0].Conf.AllowedOrigins)
		}
	}
}

func TestFull(t *testing.T) {
	conf := `cors {
  origin http://foo.com
  methods POST,PUT
  allow_credentials true
  max_age 3600
  allowed_headers X-Foo,X-bar
  exposed_headers X-SECRET
  origin http://bar.com
}`
	c := caddy.NewTestController("http", conf)
	rules, err := parseRules(c)
	if err != nil {
		t.Fatal(err)
	}
	if len(rules) != 1 {
		t.Fatalf("%d rules is bad", len(rules))
	}
	config := rules[0].Conf
	expectedOrigins := []string{"http://foo.com", "http://bar.com"}
	if !reflect.DeepEqual(config.AllowedOrigins, expectedOrigins) {
		t.Fatal("Origins don't match", config.AllowedOrigins, expectedOrigins)
	}
	if config.AllowedMethods != "POST,PUT" {
		t.Fatalf("Bad methods '%s'", config.AllowedMethods)
	}
	if *config.AllowCredentials != true {
		t.Fatalf("Wrong AllowCredentials")
	}
	if config.MaxAge != 3600 {
		t.Fatal("Wrong MaxAge")
	}
	if config.AllowedHeaders != "X-Foo,X-bar" {
		t.Fatal("AllowedHeaders")
	}
	if config.ExposedHeaders != "X-SECRET" {
		t.Fatal("ExposedHeaders")
	}
}
