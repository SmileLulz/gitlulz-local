package cmd

import (
	"fmt"
	"os"
	"github.com/SmileLulz/gitlulz-local/src/bundle"
	"github.com/spf13/cobra"
)

func newRestoreCmd() *cobra.Command {
	var bare bool
	cmd := &cobra.Command{
		Use:   "restore <bundle> <dest>",
		Short: "Restore a remote from a bundle",
		Args:  cobra.ExactArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			bundlePath, dest := args[0], args[1]
			if _, err := os.Stat(bundlePath); err != nil {
				return fmt.Errorf("bundle not found: %s", bundlePath)
			}
			if _, err := os.Stat(dest); err == nil {
				return fmt.Errorf("destination already exists: %s", dest)
			}
			if err := bundle.Restore(bundlePath, dest, bare); err != nil {
				return err
			}
			fmt.Printf("Restored into %s (bare=%v)\n", dest, bare)
			return nil
		},
	}
	cmd.Flags().BoolVar(&bare, "bare", true, "Create a bare repository (default true)")
	return cmd
}
