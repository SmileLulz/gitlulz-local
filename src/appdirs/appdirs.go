package appdirs

import (
	"os"
	"path/filepath"
)

// Home returns the user's home directory, preferring $HOME
// This matters on Termux, where os.UserHomeDir() may return "/".
func Home() (string, error) {
	if home := os.Getenv("HOME"); home != "" {
		return home, nil
	}
	return os.UserHomeDir()
}

// ConfigDir returns the per-app config directory following the XDG spec
// On Linux/macOS/Termux: $XDG_CONFIG_HOME/<app> or ~/.config/<app>.
func ConfigDir(app string) (string, error) {
	if xdg := os.Getenv("XDG_CONFIG_HOME"); xdg != "" {
		return filepath.Join(xdg, app), nil
	}
	home, err := Home()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".config", app), nil
}
