package gitops

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
)

// Run executes git with the given arguments. If dir is non-empty, git is
// invoked with -C <dir>.
func Run(dir string, args ...string) (string, error) {
	full := args
	if dir != "" {
		full = append([]string{"-C", dir}, args...)
	}
	cmd := exec.Command("git", full...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return stdout.String(), fmt.Errorf(
			"git %s: %w\n%s",
			strings.Join(full, " "), err, strings.TrimSpace(stderr.String()),
		)
	}
	return stdout.String(), nil
}

// InitBare creates a bare repository at path.
func InitBare(path, defaultBranch string) error {
	args := []string{"init", "--bare"}
	if defaultBranch != "" {
		args = append(args, "-b", defaultBranch)
	}
	args = append(args, path)
	_, err := Run("", args...)
	return err
}

// IsRepo reports whether path is a git repository.
func IsRepo(path string) bool {
	_, err := Run(path, "rev-parse", "--git-dir")
	return err == nil
}

// IsBare reports whether path is a bare repository.
func IsBare(path string) bool {
	out, err := Run(path, "rev-parse", "--is-bare-repository")
	if err != nil {
		return false
	}
	return strings.TrimSpace(out) == "true"
}
