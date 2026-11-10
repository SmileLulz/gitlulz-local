package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/SmileLulz/gitlulz-local/src/bundle"
	"github.com/SmileLulz/gitlulz-local/src/gitops"
	"github.com/spf13/cobra"
)

func newBackupCmd() *cobra.Command {
	var (
		outputDir string
		prefix    string
		asJSON    bool
	)
	cmd := &cobra.Command{
		Use:   "backup <remote-path>",
		Short: "Create a verified full bundle backup of a local remote",
		Long: `Creates a self-contained bundle (--all HEAD), verifies it, and writes a
manifest alongside it. Bundles are read-only archives; restore with
'gitlulz-local restore <bundle> <dest>'.`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			src, err := filepath.Abs(args[0])
			if err != nil {
				return err
			}
			if !gitops.IsRepo(src) {
				return fmt.Errorf("not a git repository: %s", src)
			}
			if !gitops.IsBare(src) {
				return fmt.Errorf("not a bare repository: %s", src)
			}
			if outputDir == "" {
				outputDir = filepath.Join(filepath.Dir(src), filepath.Base(src)+".backups")
			}
			if err := os.MkdirAll(outputDir, 0o755); err != nil {
				return err
			}
			if prefix == "" {
				prefix = filepath.Base(src)
			}
			m, bundlePath, manifestPath, err := bundle.CreateFull(src, outputDir, prefix, Version)
			if err != nil {
				return err
			}
			if asJSON {
				data, _ := json.MarshalIndent(m, "", "  ")
				fmt.Println(string(data))
				return nil
			}
			if m.Empty {
				fmt.Printf("Repository has no refs; wrote empty manifest:\n  %s\n", manifestPath)
				return nil
			}
			fmt.Printf("Backup created: %s\n", bundlePath)
			fmt.Printf("  manifest: %s\n", manifestPath)
			fmt.Printf("  refs:     %d\n", len(m.Refs))
			fmt.Printf("  size:     %d bytes\n", m.BundleSize)
			fmt.Printf("  sha256:   %s\n", m.BundleSHA256)
			fmt.Printf("Restore with:\n  gitlulz-local restore %s <dest>\n", bundlePath)
			return nil
		},
	}
	cmd.Flags().StringVarP(&outputDir, "output", "o", "", "Directory for bundle and manifest (default: sibling <name>.backups)")
	cmd.Flags().StringVar(&prefix, "prefix", "", "Filename prefix (default: repository directory name)")
	cmd.Flags().BoolVar(&asJSON, "json", false, "Output manifest as JSON")
	return cmd
}
