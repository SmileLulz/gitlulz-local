#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname -- "${BASH_SOURCE[0]}")"

shopt -s nullglob

echo "Removing build artifacts..."

# Compiled binary from ./build.sh go
rm -fv ./gitlulz-local
rm -fv ./gitlulz-local.exe

# Cross-compiled binaries from ./build.sh cross
rm -rfv ./dist

# Packages produced by makepkg (PKGDEST=$PWD)
rm -fv ./*.pkg.tar.zst
rm -fv ./*.pkg.tar.zst.sig
rm -fv ./*.pkg.tar.xz
rm -fv ./*.pkg.tar.xz.sig

# Per-PKGBUILD build state
for d in packaging/*/; do
    rm -rfv "${d}src"
    rm -rfv "${d}pkg"
    rm -fv "${d}"*.pkg.tar.zst
    rm -fv "${d}"*.pkg.tar.zst.sig
    rm -fv "${d}"*.src.tar.*
done

echo "Done."
