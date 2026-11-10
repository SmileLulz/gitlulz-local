package bundle

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/SmileLulz/gitlulz-local/src/gitops"
)

const (
	ManifestSuffix = ".manifest.json"
	FormatVersion  = 1
)

type Manifest struct {
	Format        string    `json:"format"`
	FormatVersion int       `json:"format_version"`
	Created       time.Time `json:"created"`
	SourcePath    string    `json:"source_path"`
	SourceHead    string    `json:"source_head,omitempty"`
	GitVersion    string    `json:"git_version"`
	ToolVersion   string    `json:"tool_version"`
	BundleFile    string    `json:"bundle_file,omitempty"`
	BundleSHA256  string    `json:"bundle_sha256,omitempty"`
	BundleSize    int64     `json:"bundle_size,omitempty"`
	Refs          []Ref     `json:"refs,omitempty"`
	Empty         bool      `json:"empty,omitempty"`
}

type Ref struct {
	Name string `json:"name"`
	OID  string `json:"oid"`
}

// HasRefs reports whether the repository has any refs.
func HasRefs(repoPath string) (bool, error) {
	out, err := gitops.Run(repoPath, "show-ref")
	if err != nil {
		if strings.Contains(err.Error(), "exit status 1") {
			return false, nil
		}
		return false, err
	}
	return strings.TrimSpace(out) != "", nil
}

// CreateFull creates a full bundle (--all HEAD) of repoPath into outputDir,
// verifies it, and writes a manifest alongside. It returns the manifest, the
// final bundle path (empty if the repository has no refs), and the manifest
// path.
func CreateFull(repoPath, outputDir, prefix, toolVersion string) (*Manifest, string, string, error) {
	if !gitops.IsBare(repoPath) {
		return nil, "", "", fmt.Errorf("%s is not a bare git repository", repoPath)
	}
	hasRefs, err := HasRefs(repoPath)
	if err != nil {
		return nil, "", "", err
	}

	stamp := time.Now().UTC().Format("20060102T150405Z")
	baseName := fmt.Sprintf("%s-%s", prefix, stamp)
	manifestPath := filepath.Join(outputDir, baseName+ManifestSuffix)

	if !hasRefs {
		m := &Manifest{
			Format:        "gitlulz-local.bundle-manifest",
			FormatVersion: FormatVersion,
			Created:       time.Now().UTC(),
			SourcePath:    repoPath,
			ToolVersion:   toolVersion,
			Empty:         true,
		}
		if err := writeJSONAtomic(manifestPath, m); err != nil {
			return nil, "", "", err
		}
		return m, "", manifestPath, nil
	}

	tmp, err := os.CreateTemp(outputDir, ".gitlulz-bundle-*")
	if err != nil {
		return nil, "", "", err
	}
	tmpPath := tmp.Name()
	tmp.Close()
	defer os.Remove(tmpPath)

	if _, err := gitops.Run(repoPath, "bundle", "create", tmpPath, "--all", "HEAD"); err != nil {
		return nil, "", "", err
	}
	if _, err := gitops.Run(repoPath, "bundle", "verify", tmpPath); err != nil {
		return nil, "", "", fmt.Errorf("bundle verification failed: %w", err)
	}
	refsOut, err := gitops.Run(repoPath, "bundle", "list-heads", tmpPath)
	if err != nil {
		return nil, "", "", err
	}
	refs := parseRefs(refsOut)

	sum, size, err := hashFile(tmpPath)
	if err != nil {
		return nil, "", "", err
	}

	gitVer, _ := gitops.Run("", "version")
	gitVer = strings.TrimSpace(gitVer)
	headOut, _ := gitops.Run(repoPath, "rev-parse", "HEAD")
	head := strings.TrimSpace(headOut)

	bundleName := baseName + ".bundle"
	finalBundlePath := filepath.Join(outputDir, bundleName)
	if err := os.Rename(tmpPath, finalBundlePath); err != nil {
		return nil, "", "", err
	}

	m := &Manifest{
		Format:        "gitlulz-local.bundle-manifest",
		FormatVersion: FormatVersion,
		Created:       time.Now().UTC(),
		SourcePath:    repoPath,
		SourceHead:    head,
		GitVersion:    gitVer,
		ToolVersion:   toolVersion,
		BundleFile:    bundleName,
		BundleSHA256:  sum,
		BundleSize:    size,
		Refs:          refs,
	}
	if err := writeJSONAtomic(manifestPath, m); err != nil {
		return nil, "", "", err
	}
	return m, finalBundlePath, manifestPath, nil
}

// VerifyBundle verifies a bundle file and returns the refs it contains.
func VerifyBundle(bundlePath string) ([]Ref, error) {
	if _, err := gitops.Run("", "bundle", "verify", bundlePath); err != nil {
		return nil, err
	}
	out, err := gitops.Run("", "bundle", "list-heads", bundlePath)
	if err != nil {
		return nil, err
	}
	return parseRefs(out), nil
}

// Restore clones from a bundle into destPath.
func Restore(bundlePath, destPath string, bare bool) error {
	args := []string{"clone"}
	if bare {
		args = append(args, "--bare")
	}
	args = append(args, bundlePath, destPath)
	_, err := gitops.Run("", args...)
	return err
}

func parseRefs(out string) []Ref {
	var refs []Ref
	for _, line := range strings.Split(out, "\n") {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		refs = append(refs, Ref{Name: fields[1], OID: fields[0]})
	}
	return refs
}

func hashFile(path string) (string, int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", 0, err
	}
	defer f.Close()
	h := sha256.New()
	n, err := io.Copy(h, f)
	if err != nil {
		return "", 0, err
	}
	return hex.EncodeToString(h.Sum(nil)), n, nil
}

func writeJSONAtomic(path string, v any) error {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	tmp, err := os.CreateTemp(filepath.Dir(path), ".gitlulz-manifest-*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpName, path)
}
