package config

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/SmileLulz/gitlulz-local/src/appdirs"
	"gopkg.in/yaml.v3"
)

// DefaultMaxBackups is used when the config file is absent or omits the field
const DefaultMaxBackups = 3

type Config struct {
	MaxBackups int `yaml:"max_backups"`
}

// Path returns the config file location
func Path() (string, error) {
	dir, err := appdirs.ConfigDir("gitlulz-local")
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "config.yaml"), nil
}

// Load reads the config file. A missing file returns defaults and a nil error;
// a malformed file returns a non-nil error
// so a typo never silently falls back to defaults.
func Load() (*Config, string, error) {
	path, err := Path()
	if err != nil {
		return nil, "", err
	}

	cfg := &Config{MaxBackups: DefaultMaxBackups}

	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return cfg, path, nil
		}
		return nil, path, err
	}

	if err := yaml.Unmarshal(data, cfg); err != nil {
		return nil, path, fmt.Errorf("parse %s: %w", path, err)
	}
	if cfg.MaxBackups < 0 {
		return nil, path, fmt.Errorf("%s: max_backups must be >= 0 (0 = unlimited)", path)
	}
	return cfg, path, nil
}

const defaultConfigTemplate = `# gitlulz-local configuration

# Keep at most this many backups per remote + prefix combination.
# 0 = unlimited (pruning disabled). Default is 3.
max_backups: %d
`

// Ensure creates the config file with defaults if it does not exist
func Ensure() (string, error) {
	path, err := Path()
	if err != nil {
		return "", err
	}
	if _, err := os.Stat(path); err == nil {
		return path, nil
	} else if !os.IsNotExist(err) {
		return path, err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return path, err
	}
	content := fmt.Sprintf(defaultConfigTemplate, DefaultMaxBackups)
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		return path, err
	}
	return path, nil
}
