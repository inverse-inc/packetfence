package radiusdictionary

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/inverse-inc/go-radius/dictionary"
)

func write(t *testing.T, path, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
}

func parse(t *testing.T, dir string) (*dictionary.Dictionary, error) {
	t.Helper()
	parser := &dictionary.Parser{Opener: &Opener{Root: dir}, IgnoreIdenticalAttributes: true, IgnoreUnknownAttributeType: true}
	return parser.ParseFile(filepath.Join(dir, "dictionary"))
}

// The optional include of FreeRADIUS is loaded when the file exists
func TestOptionalIncludePresent(t *testing.T) {
	dir := t.TempDir()
	write(t, filepath.Join(dir, "dictionary"), "ATTRIBUTE\tMain-Attr\t3000\tstring\n$INCLUDE- "+filepath.Join(dir, "dictionary.local")+"\n")
	write(t, filepath.Join(dir, "dictionary.local"), "# local attributes\nATTRIBUTE\tLocal-Attr\t3001\tinteger\n")

	d, err := parse(t, dir)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if dictionary.AttributeByName(d.Attributes, "Local-Attr") == nil {
		t.Fatal("the attribute of the optional include is missing")
	}
	if dictionary.AttributeByName(d.Attributes, "Main-Attr") == nil {
		t.Fatal("the attribute of the main dictionary is missing")
	}
}

// ... and skipped when it doesn't, like FreeRADIUS does
func TestOptionalIncludeMissing(t *testing.T) {
	dir := t.TempDir()
	write(t, filepath.Join(dir, "dictionary"), "ATTRIBUTE\tMain-Attr\t3000\tstring\n$INCLUDE- "+filepath.Join(dir, "dictionary.local")+"\n")

	d, err := parse(t, dir)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if dictionary.AttributeByName(d.Attributes, "Main-Attr") == nil {
		t.Fatal("the attribute of the main dictionary is missing")
	}
}

// A regular $INCLUDE of a missing file is still an error
func TestRegularIncludeMissing(t *testing.T) {
	dir := t.TempDir()
	write(t, filepath.Join(dir, "dictionary"), "$INCLUDE "+filepath.Join(dir, "missing")+"\n")
	if _, err := parse(t, dir); err == nil {
		t.Fatal("a missing required include must fail")
	}
}
