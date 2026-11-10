# gitlulz-local

A small CLI that makes **hosting a local Git remote** and **backing it up safely** easy. It has no runtime dependencies beyond `git` itself: every command shells out to `git`.

## Build and Install

```bash
./build-on-linux.sh go              # static binary -> ./gitlulz-local
./build-on-linux.sh cross           # cross-compile all targets -> ./dist
./build-on-linux.sh archlinux-local # build the Arch package from the work tree
```

On macOS, use `./build-on-mac.sh`; on Windows, `build-on-windows.bat`. Both expose only `go`, `test`, and `cross` (`makepkg` is Arch Linux only).

The version comes from the `VERSION` file at the project root. Bump that file to release; every build path (`go`, `cross`, and the PKGBUILD) reads it.

## Commands

| Command                                 | Purpose                                                                       |
| --------------------------------------- | ----------------------------------------------------------------------------- |
| `gitlulz-local init <path>`             | Create a bare repo (appends `.git` unless `--no-git-suffix`)                  |
| `gitlulz-local info <path>`             | Show HEAD, branches, tags                                                     |
| `gitlulz-local backup <path>`           | Full `--all HEAD` bundle + verify + manifest; writes to `<name>.backups/`     |
| `gitlulz-local restore <bundle> <dest>` | Clone a bare repo back from a bundle (default `--bare`)                       |
| `gitlulz-local verify <bundle>`         | Verify a bundle independently                                                 |
| `gitlulz-local version`                 | Version info                                                                  |

## Backup Workflow

The `.git` suffix is a convention, not a requirement, but it signals "this is a remote, not a checkout". `init` appends it automatically unless you pass `--no-git-suffix`, and `backup` trims it when naming files, so `/GitRemotes/my-project.git` and `/GitRemotes/my-project` behave identically and both produce `my-project-...` backups.

```bash
gitlulz-local init /GitRemotes/my-project
# in a working repo:
git remote add local /GitRemotes/my-project.git && git push -u local main

gitlulz-local backup /GitRemotes/my-project.git
# -> /GitRemotes/my-project.backups/my-project-YYYYMMDDTHHMMSSZ.bundle
#    + .manifest.json with SHA-256, size, refs, git/tool version

# restore anywhere:
gitlulz-local restore \
  /GitRemotes/my-project.backups/my-project-YYYYMMDDTHHMMSSZ.bundle \
  /tmp/restored.git
```

Override the output directory with `-o/--output` and the filename prefix with `--prefix`:

```bash
gitlulz-local backup /GitRemotes/my-project.git -o /mnt/nas/git-backups
```

Bundles are read-only archives; use `gitlulz-local verify <bundle>` to check one independently, and `gitlulz-local restore` to clone it back. A backup of an empty remote writes only a manifest with `"empty": true`, and no bundle.

### What a backup contains

- All refs (`refs/heads/*`, `refs/tags/*`, `refs/remotes/*`) plus every object reachable from them, via `git bundle create ... --all HEAD`.
- `HEAD` is included explicitly, so the default branch is preserved.
- Not included: reflogs, `.git/config`, hooks, `refs/notes/*`, or unreachable objects. Copy those files separately if you need them.

Each bundle is verified with `git bundle verify` before it is renamed into place, and the manifest is written atomically after the bundle, so readers never see a half-written backup.

## Testing

End-to-end smoke tests run in a temporary directory and clean up on exit:

```bash
./test-on-linux.sh
./test-on-mac.sh
test-on-windows.bat
```

Set `KEEP=1` to keep the temp directory for inspection. On Windows the `.bat` locates `bash.exe` from your Git for Windows install and runs the shared suite.

## Releases

Pushing a `v*` tag triggers `.github/workflows/release.yml`, which builds the cross binaries plus the Arch packages for `x86_64` and `aarch64`, and attaches everything to a GitHub Release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Keep `VERSION` and the tag in sync; asset filenames come from `VERSION`. Local build artifacts can be removed with `./clean.sh`.

## Architecture Support

- `./build-on-linux.sh cross` cross-compiles for: `linux/{amd64,arm64,arm,riscv64}`, `darwin/{amd64,arm64}`, `windows/{amd64,arm64}`.
- The PKGBUILD declares `arch=('x86_64' 'aarch64' 'armv7h' 'riscv64')`.
- Binaries are built with `CGO_ENABLED=0` -> fully static on Linux.
