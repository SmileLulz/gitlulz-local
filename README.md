# gitlulz-local

A small, dependency-free CLI that makes **hosting a local Git remote** and **backing it up safely** easy.

## Build and Install (Arch)

```bash
./build.sh arch-local # builds from the current work tree, installs the package
./build.sh arch-git   # builds from the current HEAD's origin URL
```

Or build a static binary directly:

```bash
./build.sh go # run it with: ./gitlulz-local
```

## Commands

| Command                                 | Purpose                                      |
| --------------------------------------- | -------------------------------------------- |
| `gitlulz-local init <path>`             | Create a bare repo (a local "remote")        |
| `gitlulz-local info <path>`             | Show HEAD, branches, tags                    |
| `gitlulz-local backup <path>`           | Full `--all HEAD` bundle + verify + manifest |
| `gitlulz-local restore <bundle> <dest>` | Clone a bare repo back from a bundle         |
| `gitlulz-local verify <bundle>`         | Verify a bundle independently                |
| `gitlulz-local version`                 | Version info                                 |

## Backup Workflow

```bash
gitlulz-local init /GitRemotes/my-project
# in a working repo:
git remote add local /GitRemotes/my-project && git push -u local main

gitlulz-local backup /GitRemotes/my-project
# -> /GitRemotes/my-project.backups/my-project-YYYYMMDDTHHMMSSZ.bundle
#    + .manifest.json with SHA-256, size, refs, git/tool version
```

## Architecture Support

- `./build.sh cross` cross-compiles for: `linux/{amd64,arm64,arm,riscv64}`, `darwin/{amd64,arm64}`, `windows/{amd64,arm64}`.
- The PKGBUILDs declare `arch=('x86_64' 'aarch64' 'armv7h' 'riscv64')`.
- Binaries are built with `CGO_ENABLED=0` -> fully static on Linux.
