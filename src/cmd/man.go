package cmd

import (
	"github.com/spf13/cobra"
	"github.com/spf13/cobra/doc"
)

func newManCmd() *cobra.Command {
	return &cobra.Command{
		Use:    "man <directory>",
		Short:  "Generate man pages",
		Hidden: true,
		Args:   cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			header := &doc.GenManHeader{
				Title:   "GITLULZ-LOCAL",
				Section: "1",
				Source:  "gitlulz-local " + Version,
				Manual:  "gitlulz-local manual",
			}
			return doc.GenManTree(rootCmd, header, args[0])
		},
	}
}
