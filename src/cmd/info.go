package cmd

import (
	"encoding/json"
	"fmt"
	"strings"
	"github.com/SmileLulz/gitlulz-local/src/gitops"
	"github.com/spf13/cobra"
)

type infoOutput struct {
	Path     string   `json:"path"`
	Bare     bool     `json:"bare"`
	Head     string   `json:"head,omitempty"`
	Branches []string `json:"branches"`
	Tags     []string `json:"tags"`
}

func newInfoCmd() *cobra.Command {
	var asJSON bool
	cmd := &cobra.Command{
		Use:   "info <path>",
		Short: "Show branches, tags and HEAD of a local remote",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			path := args[0]
			if !gitops.IsRepo(path) {
				return fmt.Errorf("not a git repository: %s", path)
			}
			head, _ := gitops.Run(path, "symbolic-ref", "--short", "HEAD")
			branchesOut, _ := gitops.Run(path, "for-each-ref", "--format=%(refname:short)", "refs/heads")
			tagsOut, _ := gitops.Run(path, "for-each-ref", "--format=%(refname:short)", "refs/tags")
			info := infoOutput{
				Path:     path,
				Bare:     gitops.IsBare(path),
				Head:     strings.TrimSpace(head),
				Branches: splitLines(branchesOut),
				Tags:     splitLines(tagsOut),
			}
			if asJSON {
				data, _ := json.MarshalIndent(info, "", "  ")
				fmt.Println(string(data))
				return nil
			}
			fmt.Printf("path: %s\n", info.Path)
			fmt.Printf("bare: %v\n", info.Bare)
			if info.Head != "" {
				fmt.Printf("head: %s\n", info.Head)
			}
			fmt.Printf("branches: %d\n", len(info.Branches))
			for _, b := range info.Branches {
				fmt.Printf("  %s\n", b)
			}
			fmt.Printf("tags: %d\n", len(info.Tags))
			for _, t := range info.Tags {
				fmt.Printf("  %s\n", t)
			}
			return nil
		},
	}
	cmd.Flags().BoolVar(&asJSON, "json", false, "Output as JSON")
	return cmd
}

func splitLines(s string) []string {
	var out []string
	for _, line := range strings.Split(s, "\n") {
		if line = strings.TrimSpace(line); line != "" {
			out = append(out, line)
		}
	}
	return out
}
