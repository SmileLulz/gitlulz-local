#!/usr/bin/env bash
# (UNTESTED SCRIPT)
# macOS build script. Same commands as build-on-linux.sh,
# minus Arch-specific packaging (makepkg is Arch Linux only).
set -euo pipefail

usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") <name|command> [extra args...]

Built-in commands:
  go             Run: go build -trimpath -buildvcs=false -ldflags="-s -w" -o gitlulz-local ./src [extra args...]
  test           Run: go test ./... [extra args...]
  cross [dir]    Cross-compile all OS/arch targets into <dir> (default: dist)
  linux [dir]    Cross-compile Linux targets only into <dir> (default: dist)
  darwin [dir]   Cross-compile macOS targets only into <dir> (default: dist)
  windows [dir]  Cross-compile Windows targets only into <dir> (default: dist)
  termux [dir]   Cross-compile Termux (Android) targets only into <dir> (default: dist)

Examples:
  $(basename "$0") go
  $(basename "$0") test
  $(basename "$0") cross
  $(basename "$0") linux
  $(basename "$0") darwin
  $(basename "$0") windows
  $(basename "$0") termux
EOF
}

project_version() {
    local f="$PWD/VERSION"
    if [[ -f "$f" ]]; then
        tr -d '[:space:]' < "$f"
    else
        echo "dev"
    fi
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

build_targets() {
    local outdir="$1"
    shift
    mkdir -p "$outdir"
    for t in "$@"; do
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

run_cross() {
    local outdir="${1:-dist}"
    build_targets "$outdir" \
        "linux/amd64" "linux/arm64" "linux/arm" "linux/riscv64" \
        "darwin/amd64" "darwin/arm64" \
        "windows/amd64" "windows/arm64" \
        "android/arm64"
}

run_linux() {
    local outdir="${1:-dist}"
    build_targets "$outdir" \
        "linux/amd64" "linux/arm64" "linux/arm" "linux/riscv64"
}

run_darwin() {
    local outdir="${1:-dist}"
    build_targets "$outdir" \
        "darwin/amd64" "darwin/arm64"
}

run_windows() {
    local outdir="${1:-dist}"
    build_targets "$outdir" \
        "windows/amd64" "windows/arm64"
}

run_termux() {
    local outdir="${1:-dist}"
    build_targets "$outdir" \
        "android/arm64"
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

case "$1" in
    -h|--help) usage; exit 0 ;;
    go)      shift; run_go "$@" ;;
    test)    shift; run_test "$@" ;;
    cross)   shift; run_cross "$@" ;;
    linux)   shift; run_linux "$@" ;;
    darwin)  shift; run_darwin "$@" ;;
    windows) shift; run_windows "$@" ;;
    termux)  shift; run_termux "$@" ;;
    *)
        echo "Error: unknown command '$1'. On macOS only go, test, cross, linux, darwin, windows, and termux are available." >&2
        usage
        exit 1
        ;;
esac
