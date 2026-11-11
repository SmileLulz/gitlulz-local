package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/SmileLulz/gitlulz-local/src/bundle"
	"github.com/SmileLulz/gitlulz-local/src/config"
	"github.com/SmileLulz/gitlulz-local/src/gitops"
	"github.com/spf13/cobra"
)

func newBackupCmd() *cobra.Command {
	var (
		outputDir      string
		prefix         string
		asJSON         bool
		maxBackupsFlag int
	)
	cmd := &cobra.Command{
		Use:   "backup <remote-path>",
		Short: "Create a verified full bundle backup of a local remote",
		Long: `Creates a self-contained bundle (--all HEAD), verifies it, and writes a
manifest alongside it. Bundles are read-only archives; restore with
'gitlulz-local restore <bundle> <dest>'.

Old backups are pruned according to max_backups in the config file (default 3).
Pass --max-backups to override for a single run. 0 means unlimited.`,
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
			base := strings.TrimSuffix(filepath.Base(src), ".git")
			if base == "" {
				base = filepath.Base(src)
			}
			if outputDir == "" {
				outputDir = filepath.Join(filepath.Dir(src), base+".backups")
			}
			if err := os.MkdirAll(outputDir, 0o755); err != nil {
				return err
			}
			if prefix == "" {
				prefix = base
			}

			cfg, cfgPath, err := config.Load()
			if err != nil {
				return fmt.Errorf("config: %w", err)
			}
			maxBackups := cfg.MaxBackups
			if cmd.Flags().Changed("max-backups") && maxBackupsFlag >= 0 {
				maxBackups = maxBackupsFlag
			}
			_ = cfgPath // reserved for future verbose output

			m, bundlePath, manifestPath, err := bundle.CreateFull(src, outputDir, prefix, Version)
			if err != nil {
				return err
			}

			pruned, pruneErr := bundle.PruneOldBackups(outputDir, prefix, maxBackups)
			if pruneErr != nil {
				fmt.Fprintf(os.Stderr, "warning: pruning failed: %v\n", pruneErr)
			}

			if asJSON {
				data, _ := json.MarshalIndent(m, "", "  ")
				fmt.Println(string(data))
				for _, p := range pruned {
					fmt.Fprintf(os.Stderr, "pruned: %s\n", p)
				}
				return nil
			}

			if m.Empty {
				fmt.Printf("Repository has no refs; wrote empty manifest:\n  %s\n", manifestPath)
			} else {
				fmt.Printf("Backup created: %s\n", bundlePath)
				fmt.Printf("  manifest: %s\n", manifestPath)
				fmt.Printf("  refs:     %d\n", len(m.Refs))
				fmt.Printf("  size:     %d bytes\n", m.BundleSize)
				fmt.Printf("  sha256:   %s\n", m.BundleSHA256)
			}
			for _, p := range pruned {
				fmt.Printf("Pruned old backup: %s\n", p)
			}
			if !m.Empty {
				fmt.Printf("Restore with:\n  gitlulz-local restore %s <dest>\n", bundlePath)
			}
			return nil
		},
	}
	cmd.Flags().StringVarP(&outputDir, "output", "o", "", "Directory for bundle and manifest (default: sibling <name>.backups)")
	cmd.Flags().StringVar(&prefix, "prefix", "", "Filename prefix (default: repository directory name)")
	cmd.Flags().BoolVar(&asJSON, "json", false, "Output manifest as JSON")
	cmd.Flags().IntVar(&maxBackupsFlag, "max-backups", -1, "Override config max_backups (0 = unlimited, default: from config)")
	return cmd
}
