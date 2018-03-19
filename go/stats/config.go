package main

import (
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// readDBConfig read pfconfig database configuration
func readDBConfig() pfconfigdriver.PfConfDatabase {
	var sections pfconfigdriver.PfConfDatabase

	pfconfigdriver.FetchDecodeSocket(ctx, &sections)
	return sections
}
