package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

// Version is set by main before Execute is called
var Version = "0.1.0-dev"

var rootCmd = &cobra.Command{
	Use:   "gitlulz-local",
	Short: "Polished local Git hosting: remote setup and verified backups",
	Long: `gitlulz-local helps you set up local bare Git remotes and back them up
as verified portable bundles that can be cloned back at any time.`,
	SilenceUsage:  true,
	SilenceErrors: true,
}

func init() {
	rootCmd.AddCommand(
		newInitCmd(),
		newInfoCmd(),
		newBackupCmd(),
		newRestoreCmd(),
		newVerifyCmd(),
		newVersionCmd(),
		newManCmd(),
	)
}

// Execute runs the root command and reports errors to stderr
func Execute() error {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		return err
	}
	return nil
}
