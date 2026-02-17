package cmd

import (
	"fmt"

	"github.com/inverse-inc/packetfence/go/version"
	"github.com/spf13/cobra"
)

// versionCmd represents the version command
var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Output version information",
	Long:  ``,
	Run: func(cmd *cobra.Command, args []string) {
		v, _ := version.VersionGetRelease()
		fmt.Println(v)
	},
}

func init() {
	pfCmd.AddCommand(versionCmd)
}
