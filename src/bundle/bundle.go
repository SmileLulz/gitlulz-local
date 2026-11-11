package bundle

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
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

// HasRefs reports whether the repository has any refs
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
// verifies it, and writes a manifest alongside. It returns the manifest,
// the final bundle path (empty if the repository has no refs),
// and the manifest path.
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

	bundleArgs := []string{"bundle", "create", tmpPath, "--all"}
	headResolves := false
	if _, err := gitops.Run(repoPath, "rev-parse", "--verify", "--quiet", "HEAD"); err == nil {
		headResolves = true
		bundleArgs = append(bundleArgs, "HEAD")
	}
	if _, err := gitops.Run(repoPath, bundleArgs...); err != nil {
		return nil, "", "", err
	}
	if !headResolves {
		fmt.Fprintf(os.Stderr,
			"warning: HEAD in %s is dangling; bundle has no default branch. "+
				"Fix with: git -C %s symbolic-ref HEAD refs/heads/<branch>\n",
			repoPath, repoPath)
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

// PruneOldBackups keeps the newest maxBackups manifests (with their bundles)
// in outputDir that share the given prefix. maxBackups == 0 disables pruning.
// Returns the list of bundle paths that were removed.
func PruneOldBackups(outputDir, prefix string, maxBackups int) ([]string, error) {
	if maxBackups <= 0 {
		return nil, nil
	}

	manifests, err := findManifests(outputDir, prefix)
	if err != nil {
		return nil, err
	}
	sort.Strings(manifests)

	if len(manifests) <= maxBackups {
		return nil, nil
	}

	toDelete := manifests[:len(manifests)-maxBackups]
	var pruned []string
	for _, manifestPath := range toDelete {
		m, err := readManifest(manifestPath)
		if err != nil {
			// A corrupt manifest means we cannot know which bundle to delete.
			// Leave both files alone and move on.
			fmt.Fprintf(os.Stderr, "warning: skipping %s: %v\n", manifestPath, err)
			continue
		}
		if m.BundleFile != "" {
			bundlePath := filepath.Join(outputDir, m.BundleFile)
			if err := os.Remove(bundlePath); err != nil && !os.IsNotExist(err) {
				return pruned, fmt.Errorf("remove %s: %w", bundlePath, err)
			}
			pruned = append(pruned, bundlePath)
		}
		if err := os.Remove(manifestPath); err != nil && !os.IsNotExist(err) {
			return pruned, fmt.Errorf("remove %s: %w", manifestPath, err)
		}
	}
	return pruned, nil
}

// findManifests returns full paths of manifest files in outputDir whose names
// begin with "<prefix>-" and end with ManifestSuffix. Uses ReadDir rather than
// filepath.Glob so a prefix containing '*' or '[' is treated literally.
func findManifests(outputDir, prefix string) ([]string, error) {
	entries, err := os.ReadDir(outputDir)
	if err != nil {
		return nil, err
	}
	filePrefix := prefix + "-"
	var matches []string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		if strings.HasPrefix(name, filePrefix) && strings.HasSuffix(name, ManifestSuffix) {
			matches = append(matches, filepath.Join(outputDir, name))
		}
	}
	return matches, nil
}

func readManifest(path string) (*Manifest, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var m Manifest
	if err := json.Unmarshal(data, &m); err != nil {
		return nil, err
	}
	return &m, nil
}

// VerifyBundle verifies a bundle file and returns the refs it contains
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

// Restore clones from a bundle into destPath
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
