package main

import (
	"os"

	"github.com/SmileLulz/gitlulz-local/src/cmd"
)

var version = "dev" // fallback version

func main() {
	cmd.Version = version
	if err := cmd.Execute(); err != nil {
		os.Exit(1)
	}
}
