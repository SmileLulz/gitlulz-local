package bundle

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseRefs(t *testing.T) {
	out := "abc123 refs/heads/main\ndef456 refs/tags/v1.0\n"
	refs := parseRefs(out)
	if len(refs) != 2 {
		t.Fatalf("expected 2 refs, got %d", len(refs))
	}
	if refs[0].Name != "refs/heads/main" || refs[0].OID != "abc123" {
		t.Errorf("unexpected first ref: %+v", refs[0])
	}
}

func TestHashFile(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "x")
	if err := os.WriteFile(p, []byte("hello"), 0o644); err != nil {
		t.Fatal(err)
	}
	sum, size, err := hashFile(p)
	if err != nil {
		t.Fatal(err)
	}
	if size != 5 {
		t.Errorf("size: want 5, got %d", size)
	}
	want := "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
	if sum != want {
		t.Errorf("sum: want %s, got %s", want, sum)
	}
}
