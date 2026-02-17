package cmd

import (
	"os"

	"github.com/spf13/cobra"
	"golang.org/x/sys/unix"
)

// pfCmd represents the base command when called without any subcommands
var pfCmd = &cobra.Command{
	Use:   "pfcmd",
	Short: "",
	Long:  ``,
	Args:  cobra.ArbitraryArgs,
	Run: func(cmd *cobra.Command, args []string) {
		unix.Exec("/usr/local/pf/bin/pfcmd.pl", os.Args, os.Environ())
		os.Exit(127)
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the pfCmd.
func Execute() {
	err := pfCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}
