```markdown
# gitlulz-local

A simple and small CLI that makes **hosting a local Git remote** and **backing it up safely** easy. It has no runtime dependencies beyond `git` itself: every command shells out to `git`.

<br>

> [!IMPORTANT]
> I built this project for my personal usecase. And I'm not accepting any contribution for now. Please fork it if you want to add/modify something. _(This project is under [GNU General Public License v3.0 only](https://github.com/SmileLulz/gitlulz-local/blob/main/LICENSE) license)._

<br>

## Build and Install

```bash
./build-on-linux.sh go              # static binary -> ./gitlulz-local
./build-on-linux.sh cross           # cross-compile everything -> ./dist
./build-on-linux.sh linux           # Linux targets only -> ./dist
./build-on-linux.sh darwin          # macOS targets only -> ./dist
./build-on-linux.sh windows         # Windows targets only -> ./dist
./build-on-linux.sh termux          # Termux (Android) target -> ./dist
./build-on-linux.sh archlinux-local # build the Arch package from the work tree
```

On macOS, use `./build-on-mac.sh`; on Windows, `build-on-windows.bat`. Both expose the same `go`, `test`, `cross`, `linux`, `darwin`, `windows`, and `termux` subcommands; only the Linux script has the `makepkg` fallback (`makepkg` is Arch Linux only).

All cross-compiled binaries land in `dist/` and follow the same `gitlulz-local-<os>-<arch>` naming, so a file produced by `cross` and the same file produced by `linux`/`darwin`/`windows`/`termux` are byte-identical. The Termux build targets `android/arm64` only: `android/arm` (32-bit Android) always requires cgo and is deliberately not built.

The version comes from the `VERSION` file at the project root. Bump that file to release; every build path (`go`, `cross`, the per-OS commands, and the PKGBUILD) reads it.

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

## Configuration

`backup` reads an optional YAML config file from:

- `$XDG_CONFIG_HOME/gitlulz-local/config.yaml` (when `XDG_CONFIG_HOME` is set), or
- `~/.config/gitlulz-local/config.yaml`

On first run, the tool writes a default `config.yaml` to that location. Delete the file to reset to defaults; the next command recreates it. `--help` and bare `gitlulz-local` (no subcommand) do not create it, so the file appears the first time you actually run a command.

On Termux the file lives at the same path relative to `$HOME`, because the tool prefers `$HOME` over `os.UserHomeDir()` (which can return `/` on Android). A missing file means defaults apply.

```yaml
# Keep at most 3 backups per remote+prefix combination.
# 0 means unlimited (pruning disabled). Default is 3.
max_backups: 3
```

Pruning runs **after** each successful backup, never before: if `git bundle create` or `git bundle verify` fails, no old backups are touched. Files considered for pruning are those matching `<prefix>-*.manifest.json` in the backup's output directory, so backups of different remotes, or of the same remote into different `-o` directories, are pruned independently. Empty-repo backups (manifest only, no bundle) are counted the same as full backups.

Override the config for a single run:

```bash
gitlulz-local backup /GitRemotes/my-project.git --max-backups 0    # unlimited
gitlulz-local backup /GitRemotes/my-project.git --max-backups 10   # keep 10
```

A malformed config file is a hard error: the run stops before creating a backup, so a typo in `config.yaml` never silently falls back to the default of 3.

## Testing

End-to-end smoke tests run in a temporary directory and clean up on exit:

```bash
./test-on-linux.sh
./test-on-mac.sh
test-on-windows.bat
./test-on-termux.sh
```

Each script checks that every command it invokes is present **before** building or running anything, and reports all missing ones at once with a platform-appropriate install hint (`pacman`/`apt`/`dnf`/`zypper`/`apk` on Linux, `brew`/`port` on macOS, `pkg install` on Termux, and `bash.exe`/`git.exe`/`go.exe` lookups on Windows). So a bare machine fails with a single readable message instead of a half-finished run.

Set `KEEP=1` to keep the temp directory for inspection. On Windows the `.bat` locates `bash.exe` from your Git for Windows install and runs the shared suite; `test-on-linux.sh` and `test-on-mac.sh` are otherwise identical apart from the install hints in the pre-check. Each script also isolates `HOME` and `XDG_CONFIG_HOME` inside the temp directory, so the config-pruning test exercises a throwaway `config.yaml` and never touches your real one.

## Releases

Pushing a `v*` tag triggers `.github/workflows/release.yml`, which builds the cross binaries plus the Arch packages for `x86_64` and `aarch64`, and attaches everything to a GitHub Release:

```bash
git tag v1.2.0
git push origin v1.2.0
```

Keep `VERSION` and the tag in sync; asset filenames come from `VERSION`. Local build artifacts can be removed with `./clean.sh`.

## Architecture Support

- `./build-on-linux.sh cross` cross-compiles for: `linux/{amd64,arm64,arm,riscv64}`, `darwin/{amd64,arm64}`, `windows/{amd64,arm64}`, `android/arm64` (Termux).
- `android/arm` (32-bit Android) is intentionally not built: it always requires cgo linking, which the other targets do not use.
- The PKGBUILD declares `arch=('x86_64' 'aarch64' 'armv7h' 'riscv64')`.
- Binaries are built with `CGO_ENABLED=0` -> fully static on Linux. The `android/arm64` build uses Go's direct Bionic dynamic imports and needs no C toolchain, so it builds on any host with Go installed.
