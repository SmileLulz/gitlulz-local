#!/data/data/com.termux/files/usr/bin/bash
# (UNTESTED SCRIPT)
# End-to-end smoke test for gitlulz-local (Termux).
# Everything lives under a single temp directory and is removed on exit
# unless KEEP=1 is set.
#
# Run it as ./test-on-termux.sh (the shebang above is Termux's fixed bash
# path). Do NOT run from /sdcard: that mount is noexec and has no Unix
# permission bits, so go build succeeds but the produced binary cannot run.
set -euo pipefail

# ==== package checks ====

pkg_hint() {
    case "$1" in
        git)             echo "pkg install git" ;;
        go)              echo "pkg install golang" ;;
        sha256sum|mktemp|basename|tr|mkdir|chmod|rm|cp|dirname)
                         echo "pkg install coreutils" ;;
        find)            echo "pkg install findutils" ;;
        sed)             echo "pkg install sed" ;;
        grep)            echo "pkg install grep" ;;
        awk)             echo "pkg install gawk" ;;
        *)               echo "(no package hint for '$1')" ;;
    esac
}

missing=()
for cmd in git go sha256sum mktemp sed grep awk find basename tr dirname; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing+=("$cmd")
    fi
done

if [ ${#missing[@]} -gt 0 ]; then
    {
        echo "error: missing required command(s):"
        for cmd in "${missing[@]}"; do
            printf '  %-10s -> %s\n' "$cmd" "$(pkg_hint "$cmd")"
        done
        echo
        echo "This script is meant to run inside Termux, where those packages"
        echo "come from 'pkg install'. If you are not on Termux, use"
        echo "test-on-linux.sh or test-on-mac.sh instead."
    } >&2
    exit 1
fi

if [ ! -f go.mod ] || [ ! -d src ]; then
    {
        echo "error: go.mod and src/ must exist in the current directory"
        echo "(run this script from the project root)"
    } >&2
    exit 1
fi

# TMPDIR is set by Termux's login environment; fall back to $PREFIX/tmp
# if it was stripped, since /tmp does not exist on Termux.
TMP_ROOT="${TMPDIR:-${PREFIX:-/data/data/com.termux/files/usr}/tmp}"
if [ ! -d "$TMP_ROOT" ]; then
    mkdir -p "$TMP_ROOT"
fi

ROOT="$(mktemp -d "$TMP_ROOT/gitlulz-test.XXXXXX")"
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
export XDG_CONFIG_HOME="$ROOT/xdg"
mkdir -p "$HOME" "$XDG_CONFIG_HOME"
export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME="gitlulz-test"
export GIT_AUTHOR_EMAIL="test@example.invalid"
export GIT_COMMITTER_NAME="gitlulz-test"
export GIT_COMMITTER_EMAIL="test@example.invalid"

BIN="$ROOT/gitlulz-local"
printf 'building test binary (native android/arm64)...\n'
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
    assert_contains "version prints android" "$out" "android/arm64"
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

test_config_auto_create() {
    local xdg="$ROOT/xdg-autocreate"
    rm -rf "$xdg"
    mkdir -p "$xdg"

    XDG_CONFIG_HOME="$xdg" "$BIN" version >/dev/null 2>&1 \
        || { not_ok "config auto-create: version runs"; return; }

    local cfg="$xdg/gitlulz-local/config.yaml"
    if [ -f "$cfg" ]; then
        ok "config auto-create: file written"
    else
        not_ok "config auto-create: file written" "missing: $cfg"
        return
    fi

    if grep -q 'max_backups: 3' "$cfg"; then
        ok "config auto-create: default max_backups"
    else
        not_ok "config auto-create: default max_backups"
    fi
}

test_config_max_backups() {
    local remote="$ROOT/pruneme.git"
    local work="$ROOT/pruneme-work"
    local xdg="$ROOT/xdg-prune"
    mkdir -p "$xdg/gitlulz-local"
    printf 'max_backups: 2\n' > "$xdg/gitlulz-local/config.yaml"

    "$BIN" init "$remote" >/dev/null 2>&1 || { not_ok "prune init"; return; }
    seed_repo "$work" "$remote"              || { not_ok "prune seed"; return; }

    local bdir="$ROOT/pruneme.backups"
    local i
    for i in 1 2 3; do
        [ "$i" -gt 1 ] && sleep 1
        XDG_CONFIG_HOME="$xdg" "$BIN" backup "$remote" >/dev/null 2>&1 \
            || { not_ok "prune backup $i"; return; }
    done

    local manifests=( "$bdir"/*.manifest.json )
    assert_eq "prune keeps only max_backups manifests" "${#manifests[@]}" "2"
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
run_test "config: auto-create"         test_config_auto_create
run_test "backup: max_backups"         test_config_max_backups
run_test "end-to-end"                  test_end_to_end
set -e

printf '\npassed: %d, failed: %d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
