#!/usr/bin/env bash
# End-to-end smoke test for gitlulz-local.
# Everything lives under a single temp directory and is removed on exit
# unless KEEP=1 is set.
set -euo pipefail

# ==== package checks ====

detect_pm() {
    local pm
    for pm in pacman apt dnf zypper apk; do
        if command -v "$pm" >/dev/null 2>&1; then
            printf '%s\n' "$pm"
            return 0
        fi
    done
    printf '\n'
}

pm_install_hint() {
    case "$(detect_pm)" in
        pacman) printf '  sudo pacman -S git go gawk\n' ;;
        apt)    printf '  sudo apt install git golang gawk\n' ;;
        dnf)    printf '  sudo dnf install git golang gawk\n' ;;
        zypper) printf '  sudo zypper install git go gawk\n' ;;
        apk)    printf '  sudo apk add git go gawk\n' ;;
        *)      printf '  (install git, go, and coreutils/findutils for your distro)\n' ;;
    esac
}

missing=()
for cmd in git go awk sed grep mktemp basename dirname mkdir chmod rm; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing+=("$cmd")
    fi
done
if ! command -v sha256sum >/dev/null 2>&1 \
   && ! command -v shasum >/dev/null 2>&1; then
    missing+=("sha256sum (or shasum)")
fi

if [ ${#missing[@]} -gt 0 ]; then
    {
        echo "error: missing required command(s):"
        for cmd in "${missing[@]}"; do
            printf '  %s\n' "$cmd"
        done
        echo
        echo "Install hint for this distro:"
        pm_install_hint
        echo
        echo "This script is meant for Linux. On macOS use ./test-on-mac.sh;"
        echo "on Termux use ./test-on-termux.sh; on Windows use test-on-windows.bat."
    } >&2
    exit 1
fi

# ==== run ====

cd "$(dirname -- "${BASH_SOURCE[0]}")"

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/gitlulz-test.XXXXXX")"
cleanup() {
    if [ -n "${KEEP:-}" ]; then
        printf 'keeping test dir: %s\n' "$ROOT" >&2
        return
    fi
    chmod -R u+w "$ROOT" 2>/dev/null || true
    rm -rf "$ROOT"
}
trap cleanup EXIT

export HOME="$ROOT/home"
mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME="gitlulz-test"
export GIT_AUTHOR_EMAIL="test@example.invalid"
export GIT_COMMITTER_NAME="gitlulz-test"
export GIT_COMMITTER_EMAIL="test@example.invalid"

BIN="$ROOT/gitlulz-local"
printf 'building test binary...\n'
go build -trimpath -buildvcs=false -o "$BIN" ./src

shopt -s nullglob

pass=0
fail=0

ok() {
    pass=$((pass + 1))
    printf 'ok   %s\n' "$1"
}

not_ok() {
    fail=$((fail + 1))
    printf 'FAIL %s\n' "$1"
    if [ -n "${2:-}" ]; then printf '     %s\n' "$2"; fi
}

assert_file() {
    if [ -f "$2" ]; then ok "$1"; else not_ok "$1" "missing file: $2"; fi
}

assert_no_file() {
    if [ ! -e "$2" ]; then ok "$1"; else not_ok "$1" "unexpected file: $2"; fi
}

assert_eq() {
    if [ "$2" = "$3" ]; then ok "$1"; else not_ok "$1" "expected '$3', got '$2'"; fi
}

assert_contains() {
    case "$2" in
        *"$3"*) ok "$1" ;;
        *) not_ok "$1" "missing '$3' in: $2" ;;
    esac
}

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

seed_repo() {
    local work="$1" remote="$2"
    mkdir -p "$work"
    git -C "$work" init -q -b main                       || return 1
    echo "hello" > "$work/file.txt"
    git -C "$work" add file.txt                          || return 1
    git -C "$work" commit -q -m "first"                  || return 1
    git -C "$work" tag v1
    git -C "$work" remote add local "$remote"            || return 1
    git -C "$work" push -q local main                    || return 1
    git -C "$work" push -q local --tags                  || return 1
}

test_version() {
    local out
    out="$("$BIN" version 2>/dev/null)" || { not_ok "version runs"; return; }
    assert_contains "version prints name" "$out" "gitlulz-local"
}

test_init_appends_suffix() {
    local p="$ROOT/init-appends"
    "$BIN" init "$p" >/dev/null 2>&1 \
        || { not_ok "init appends .git" "init failed"; return; }
    assert_file "init appends .git" "$p.git/HEAD"
    assert_no_file "init does not double-append" "$p"
}

test_init_keeps_suffix() {
    local p="$ROOT/init-keeps.git"
    "$BIN" init "$p" >/dev/null 2>&1 \
        || { not_ok "init keeps .git" "init failed"; return; }
    assert_file "init keeps .git" "$p/HEAD"
    assert_no_file "init does not double-append .git" "$p.git"
}

test_init_no_suffix_flag() {
    local p="$ROOT/init-nosuffix"
    "$BIN" init "$p" --no-git-suffix >/dev/null 2>&1 \
        || { not_ok "init --no-git-suffix" "init failed"; return; }
    assert_file "init --no-git-suffix keeps path" "$p/HEAD"
    assert_no_file "init --no-git-suffix appends nothing" "$p.git"
}

test_init_existing_fails() {
    local p="$ROOT/init-exists.git"
    mkdir -p "$p"
    if "$BIN" init "$ROOT/init-exists" >/dev/null 2>&1; then
        not_ok "init fails on existing path"
    else
        ok "init fails on existing path"
    fi
}

test_info_bare() {
    local p="$ROOT/info-bare.git"
    "$BIN" init "$p" >/dev/null 2>&1 || { not_ok "info bare"; return; }
    local out
    out="$("$BIN" info "$p" 2>/dev/null)" || { not_ok "info runs"; return; }
    assert_contains "info reports bare: true" "$out" "bare: true"
    assert_contains "info reports 0 branches" "$out" "branches: 0"
    assert_contains "info reports 0 tags" "$out" "tags: 0"
}

test_info_json() {
    local p="$ROOT/info-json.git"
    "$BIN" init "$p" >/dev/null 2>&1 || { not_ok "info --json"; return; }
    local out
    out="$("$BIN" info "$p" --json 2>/dev/null)" || { not_ok "info --json runs"; return; }
    assert_contains "info --json emits path" "$out" '"path"'
    assert_contains "info --json emits bare: true" "$out" '"bare": true'
    assert_contains "info --json emits branches" "$out" '"branches"'
}

test_backup_empty_writes_manifest_only() {
    local p="$ROOT/backup-empty.git"
    "$BIN" init "$p" >/dev/null 2>&1 || { not_ok "backup empty"; return; }
    "$BIN" backup "$p" >/dev/null 2>&1 || { not_ok "backup empty runs"; return; }

    local bdir="$ROOT/backup-empty.backups"
    local manifests=( "$bdir"/*.manifest.json )
    local bundles=( "$bdir"/*.bundle )

    if [ ! -f "${manifests[0]:-}" ]; then
        not_ok "empty backup writes manifest"; return
    fi
    ok "empty backup writes manifest"

    if [ -f "${bundles[0]:-}" ]; then
        not_ok "empty backup should not write bundle" "found: ${bundles[0]}"
    else
        ok "empty backup does not write bundle"
    fi

    if grep -q '"empty": true' "${manifests[0]}"; then
        ok "empty manifest is flagged"
    else
        not_ok "empty manifest is flagged"
    fi
}

test_backup_trims_dot_git() {
    local remote="$ROOT/trimme.git"
    local work="$ROOT/trimme-work"
    "$BIN" init "$remote" >/dev/null 2>&1 || { not_ok "trim init"; return; }
    seed_repo "$work" "$remote"              || { not_ok "trim seed"; return; }

    "$BIN" backup "$remote" >/dev/null || { not_ok "trim backup"; return; }

    local bdir="$ROOT/trimme.backups"
    local bundles=( "$bdir"/*.bundle )
    if [ ! -f "${bundles[0]:-}" ]; then
        not_ok "trim backup wrote bundle"; return
    fi
    ok "trim backup wrote bundle"

    local name; name="$(basename "${bundles[0]}")"
    case "$name" in
        trimme-*)     ok "backup name trims .git suffix" ;;
        trimme.git-*) not_ok "backup name trims .git suffix" "got: $name" ;;
        *)            not_ok "backup name trims .git suffix" "unexpected name: $name" ;;
    esac
}

test_backup_custom_output_and_prefix() {
    local remote="$ROOT/customout.git"
    local work="$ROOT/customout-work"
    local odir="$ROOT/custom-out"
    "$BIN" init "$remote" >/dev/null 2>&1 || { not_ok "custom output"; return; }
    seed_repo "$work" "$remote"              || { not_ok "custom seed"; return; }

    "$BIN" backup "$remote" -o "$odir" --prefix custom >/dev/null \
        || { not_ok "custom output runs"; return; }

    local bundles=( "$odir"/*.bundle )
    if [ ! -f "${bundles[0]:-}" ]; then
        not_ok "custom output wrote bundle"; return
    fi
    ok "custom output wrote bundle"

    local name; name="$(basename "${bundles[0]}")"
    case "$name" in
        custom-*) ok "custom prefix is used" ;;
        *)        not_ok "custom prefix is used" "got: $name" ;;
    esac
}

test_end_to_end() {
    local remote="$ROOT/e2e-remote.git"
    local work="$ROOT/e2e-work"
    local restored="$ROOT/e2e-restored.git"

    "$BIN" init "$remote" >/dev/null 2>&1 || { not_ok "e2e init"; return; }
    seed_repo "$work" "$remote"              || { not_ok "e2e seed"; return; }
    ok "e2e push"

    "$BIN" backup "$remote" >/dev/null || { not_ok "e2e backup"; return; }

    local bdir="$ROOT/e2e-remote.backups"
    local bundles=( "$bdir"/*.bundle )
    local manifests=( "$bdir"/*.manifest.json )
    if [ ! -f "${bundles[0]:-}" ]; then not_ok "e2e bundle written"; return; fi
    if [ ! -f "${manifests[0]:-}" ]; then not_ok "e2e manifest written"; return; fi
    ok "e2e bundle written"
    ok "e2e manifest written"

    if "$BIN" verify "${bundles[0]}" >/dev/null 2>&1; then
        ok "e2e verify passes"
    else
        not_ok "e2e verify passes"
    fi

    local want have
    want="$(sed -nE 's/.*"bundle_sha256": "([a-f0-9]+)".*/\1/p' "${manifests[0]}")"
    have="$(sha256_of "${bundles[0]}")"
    assert_eq "e2e manifest sha256 matches bundle" "$have" "$want"

    "$BIN" restore "${bundles[0]}" "$restored" >/dev/null 2>&1 \
        || { not_ok "e2e restore"; return; }
    ok "e2e restore"

    local refs_orig refs_new
    refs_orig="$(git -C "$remote"   for-each-ref --format='%(refname) %(objectname)')"
    refs_new="$(git -C "$restored"  for-each-ref --format='%(refname) %(objectname)')"
    assert_eq "e2e restored refs match original" "$refs_new" "$refs_orig"

    local content
    content="$(git -C "$restored" show main:file.txt 2>/dev/null || true)"
    assert_eq "e2e restored file content matches" "$content" "hello"
}

run_test() {
    printf '== %s\n' "$1"
    shift
    set +e
    "$@"
    set -e
}

set +e
run_test "version"                     test_version
run_test "init: appends .git"          test_init_appends_suffix
run_test "init: keeps .git"            test_init_keeps_suffix
run_test "init: --no-git-suffix"       test_init_no_suffix_flag
run_test "init: existing path fails"   test_init_existing_fails
run_test "info: bare"                  test_info_bare
run_test "info: --json"                test_info_json
run_test "backup: empty"               test_backup_empty_writes_manifest_only
run_test "backup: trims .git"          test_backup_trims_dot_git
run_test "backup: -o and --prefix"     test_backup_custom_output_and_prefix
run_test "end-to-end"                  test_end_to_end
set -e

printf '\npassed: %d, failed: %d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
