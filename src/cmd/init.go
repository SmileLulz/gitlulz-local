package cmd

import (
	"fmt"
	"os"
	"github.com/SmileLulz/gitlulz-local/src/gitops"
	"github.com/spf13/cobra"
)

func newInitCmd() *cobra.Command {
	var branch string
	cmd := &cobra.Command{
		Use:   "init <path>",
		Short: "Create a bare repository suitable for use as a local remote",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			path := args[0]
			if _, err := os.Stat(path); err == nil {
				return fmt.Errorf("path already exists: %s", path)
			}
			if err := gitops.InitBare(path, branch); err != nil {
				return err
			}
			fmt.Printf("Created bare repository at %s\n", path)
			fmt.Printf("Add it to a working repo with:\n  git remote add local %s\n", path)
			return nil
		},
	}
	cmd.Flags().StringVarP(&branch, "branch", "b", "", "Initial branch name (default: git's own default)")
	return cmd
}
