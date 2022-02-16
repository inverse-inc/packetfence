package maint

import (
	"io/ioutil"
	"os"
	"testing"
)

func TestFileLogger(t *testing.T) {
	tmpfile, err := ioutil.TempFile("", "*")
	if err != nil {
		t.Fatalf("Cannot create tempfile: %s", err.Error())
	}

	content := "content\n"

	name := tmpfile.Name()
	tmpfile.Close()
	defer os.Remove(name)
	logger := NewFileLogger(
		map[string]interface{}{
			"type":        "file_logger",
			"status":      "enabled",
			"description": "Test",
			"schedule":    "@every 1m",
			"outfile":     name,
			"content":     "content\n",
			"local":       "1",
		},
	)

	logger.Run()

	b, err := os.ReadFile(name)
	if err != nil {
		t.Fatalf("Cannot read from tempfile %s: %s", name, err.Error())
	}

	if content != string(b) {
		t.Fatalf("File is not append content to")
	}
}
