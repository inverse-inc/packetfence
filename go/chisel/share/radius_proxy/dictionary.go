package radius_proxy

import "github.com/inverse-inc/go-radius/dictionary"

var radiusDictionary *dictionary.Dictionary

const radisDictionaryFile = "/usr/share/freeradius/dictionary"

func init() {
	parser := &dictionary.Parser{
		Opener: &dictionary.FileSystemOpener{
			Root: "/usr/share/freeradius",
		},
		IgnoreIdenticalAttributes:  true,
		IgnoreUnknownAttributeType: true,
	}

	var err error
	if radiusDictionary, err = parser.ParseFile(radisDictionaryFile); err != nil {
		panic(err)
	}

}
