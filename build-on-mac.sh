#!/usr/bin/env bash
# macOS build script. Same commands as build-on-linux.sh,
# minus Arch-specific packaging (makepkg is Arch Linux only).
# Portable on BSD find.
set -euo pipefail

project_version() {
    local f="$PWD/VERSION"
    if [[ -f "$f" ]]; then
        tr -d '[:space:]' < "$f"
    else
        echo "dev"
    fi
}

usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") <name|command> [extra args...]

Built-in commands:
  go            Run: go build -trimpath -buildvcs=false -ldflags="-s -w -X main.version=... -o gitlulz-local ./src [extra args...]
  test          Run: go test ./... [extra args...]
  cross [dir]   Cross-compile for common OS/arch targets into <dir> (default: dist)

Examples:
  $(basename "$0") go
  $(basename "$0") test
  $(basename "$0") cross
EOF
}

run_go() {
    CGO_ENABLED=0 exec go build \
        -trimpath -buildvcs=false \
        -ldflags="-s -w -X main.version=$(project_version)" \
        -o gitlulz-local ./src "$@"
}

run_test() {
    exec go test ./... "$@"
}

run_cross() {
    local outdir="${1:-dist}"
    mkdir -p "$outdir"
    local targets=(
        "linux/amd64"  "linux/arm64" "linux/arm" "linux/riscv64"
        "darwin/amd64" "darwin/arm64"
        "windows/amd64" "windows/arm64"
    )
    for t in "${targets[@]}"; do
        local os="${t%/*}" arch="${t#*/}"
        local out="$outdir/gitlulz-local-$os-$arch"
        [[ "$os" == "windows" ]] && out+=".exe"
        local envs=("CGO_ENABLED=0" "GOOS=$os" "GOARCH=$arch")
        [[ "$arch" == "arm" ]] && envs+=("GOARM=7")
        echo "building $os/$arch -> $out"
        env "${envs[@]}" go build \
            -trimpath -buildvcs=false \
            -ldflags="-s -w -X main.version=$(project_version)" \
            -o "$out" ./src
    done
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

case "$1" in
    -h|--help) usage; exit 0 ;;
    go)   shift; run_go "$@" ;;
    test) shift; run_test "$@" ;;
    cross) shift; run_cross "$@" ;;
    *)
        echo "Error: unknown command '$1'. On macOS only go, test, and cross are available." >&2
        usage
        exit 1
        ;;
esac
