package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/SmileLulz/gitlulz-local/src/gitops"
	"github.com/spf13/cobra"
)

func newInitCmd() *cobra.Command {
	var (
		branch      string
		noGitSuffix bool
	)
	cmd := &cobra.Command{
		Use:   "init <path>",
		Short: "Create a bare repository suitable for use as a local remote",
		Long: `Create a bare repository at <path>. By default a .git suffix is appended if
the path does not already end in .git, matching 'git clone --bare'. Pass
--no-git-suffix to keep the path exactly as given.`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			path := filepath.Clean(args[0])

			if !noGitSuffix && !strings.HasSuffix(path, ".git") {
				path += ".git"
				fmt.Printf("Appending .git suffix: %s\n", path)
			}

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
	cmd.Flags().StringVarP(&branch, "branch", "b", "main", "Initial branch name")
	cmd.Flags().BoolVar(&noGitSuffix, "no-git-suffix", false, "Keep the path exactly as given; do not append .git")
	return cmd
}
