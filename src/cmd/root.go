package cmd

import (
	"fmt"
	"os"

	"github.com/SmileLulz/gitlulz-local/src/config"
	"github.com/spf13/cobra"
)

var Version = "dev"

var rootCmd = &cobra.Command{
	Use:   "gitlulz-local",
	Short: "Polished local Git hosting: remote setup and verified backups",
	Long: `gitlulz-local helps you set up local bare Git remotes and back them up
as verified portable bundles that can be cloned back at any time.`,
	SilenceUsage:  true,
	SilenceErrors: true,
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		if _, err := config.Ensure(); err != nil {
			fmt.Fprintf(os.Stderr, "warning: could not prepare config file: %v\n", err)
		}
	},
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

func Execute() error {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		return err
	}
	return nil
}
