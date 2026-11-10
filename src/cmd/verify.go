package cmd

import (
	"fmt"

	"github.com/SmileLulz/gitlulz-local/src/bundle"
	"github.com/spf13/cobra"
)

func newVerifyCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "verify <bundle>",
		Short: "Verify a bundle file and list its refs",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			refs, err := bundle.VerifyBundle(args[0])
			if err != nil {
				return err
			}
			fmt.Printf("Bundle OK (%d refs)\n", len(refs))
			for _, r := range refs {
				oid := r.OID
				if len(oid) > 12 {
					oid = oid[:12]
				}
				fmt.Printf("  %s %s\n", oid, r.Name)
			}
			return nil
		},
	}
}
