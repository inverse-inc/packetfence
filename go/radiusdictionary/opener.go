// Package radiusdictionary loads the RADIUS dictionaries of PacketFence with
// the go-radius dictionary parser.
package radiusdictionary

import (
	"bufio"
	"bytes"
	"os"
	"path/filepath"
	"strings"

	"github.com/inverse-inc/go-radius/dictionary"
)

// Opener opens the dictionary files like dictionary.FileSystemOpener, and
// handles the optional include of FreeRADIUS ("$INCLUDE- <file>", used for
// conf/radiusd/dictionary.local), which the parser doesn't know: it becomes
// a regular $INCLUDE when the file exists and is dropped otherwise.
type Opener struct {
	// Root resolves the relative paths, as in dictionary.FileSystemOpener
	Root string
}

type rewrittenFile struct {
	*bytes.Reader
	name string
}

func (f *rewrittenFile) Close() error { return nil }
func (f *rewrittenFile) Name() string { return f.name }

func (o *Opener) path(name string) string {
	if !filepath.IsAbs(name) {
		return filepath.Join(o.Root, name)
	}
	return name
}

// OpenFile implements dictionary.Opener
func (o *Opener) OpenFile(name string) (dictionary.File, error) {
	data, err := os.ReadFile(o.path(name))
	if err != nil {
		return nil, err
	}
	var out bytes.Buffer
	scanner := bufio.NewScanner(bytes.NewReader(data))
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for scanner.Scan() {
		line := scanner.Text()
		if fields := strings.Fields(line); len(fields) == 2 && fields[0] == "$INCLUDE-" {
			if _, err := os.Stat(o.path(fields[1])); err == nil {
				line = "$INCLUDE " + fields[1]
			} else {
				line = "# " + line + " (not found, skipped)"
			}
		}
		out.WriteString(line)
		out.WriteByte('\n')
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return &rewrittenFile{Reader: bytes.NewReader(out.Bytes()), name: name}, nil
}

// NewParser returns the parser PacketFence uses for its dictionaries: relative
// paths from the FreeRADIUS dictionaries, optional includes supported.
func NewParser() *dictionary.Parser {
	return &dictionary.Parser{
		Opener:                     &Opener{Root: "/usr/share/freeradius"},
		IgnoreIdenticalAttributes:  true,
		IgnoreUnknownAttributeType: true,
	}
}
