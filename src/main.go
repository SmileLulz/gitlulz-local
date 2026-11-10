package main

import (
	"os"

	"github.com/SmileLulz/gitlulz-local/src/cmd"
)

// version is overridden at build time via -ldflags "-X main.version=..."
var version = "0.1.0-dev"

func main() {
	cmd.Version = version
	if err := cmd.Execute(); err != nil {
		os.Exit(1)
	}
}
