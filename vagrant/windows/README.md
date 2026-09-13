# Windows work-laptop kit

Builds an offline kit onto a USB stick: applications, Python wheels, npm tools and a
pre-built Neovim setup that install on a locked-down Windows laptop with **no admin
rights, no network, no Scoop and no GitHub access**.

Two disposable VMs do the work. Git holds every input; the stick holds derived output
plus the dotfiles repository.

```text
 host (Arch)                      builder VM (online, MSVC)          work VM (offline)
 ───────────                      ─────────────────────────          ─────────────────
 kit/packages.json  ─ just lock ─> kit/*.lock ─ just build ─> USB:\kit\ ─ install.ps1 ─> apps, PATH, env,
 (what you want)                   (urls, hashes,   download, verify,      test.ps1       nvim, wheels,
                                    pinned deps)    compile, zip                          dotfiles clone

 ~/code/work/dotfiles ─ git push ─> USB:\repositories\work\dotfiles.git <─ git push ─ edits made in a VM
```

Box credentials are `vagrant` / `vagrant`; the work VM also has a non-admin
`worker` / `worker`.

## Requirements

| Host | Used for |
| --- | --- |
| `vagrant` + `vagrant-libvirt`, `libvirt`, `qemu` | the VMs and USB passthrough |
| `just` | the commands below |
| `gh` (authenticated), `jq`, `curl` | resolving release assets and hashes |
| `uv`, `npm` | the Python and npm lock files |
| `udisks2` (`udisksctl`), `util-linux` | mounting and releasing the stick |
| `virt-manager` | `just console` |

A USB stick labelled `portable` (override with `KIT_USB_LABEL`), formatted exFAT or
NTFS so Windows can mount it.

## Layout

| Path | Role |
| --- | --- |
| `kit/packages.json` | The file you edit: applications, Python tools, treesitter parsers, dotfiles wiring, environment variables. See [docs/manifest.md](docs/manifest.md). |
| `kit/packages.lock.json`, `kit/python/requirements.txt`, `kit/node/package-lock.json` | Generated pins. Commit them. |
| `kit/build.ps1` | Runs in `builder`. Downloads, verifies, unpacks, compiles, writes `USB:\kit\`. |
| `kit/install.ps1`, `kit/test.ps1`, `kit/Kit.psm1` | Copied to the stick; run at work and in both VMs. |
| `kit/nvim-build.lua` | Compiles treesitter parsers inside headless Neovim. |
| `Vagrantfile`, `config/`, `provision/` | The two VMs and their provisioning. |
| `scripts/` | Host-side tooling: lock, outdated, check, stick, USB passthrough. |
| `docs/` | [design](docs/design.md), [manifest](docs/manifest.md), [neovim](docs/neovim.md). |

## Commands

```sh
just              # list every command
just check        # manifest, lock files, scripts, Vagrantfile
just lock         # resolve inputs into lock files (--upgrade also bumps python/npm deps)
just outdated     # apps with newer upstream releases
just builder      # online VM: toolchain, build the kit onto the stick, install it
just build        # rebuild onto the stick and reinstall, without recreating the VM
just work         # offline VM: install from the stick, then smoke-test
just stick        # what is on the stick right now
just console      # open a VM desktop
just destroy      # remove both VMs
```

## First run

```sh
just builder                   # Build Tools install plus a full build: allow ~30 minutes
just destroy && just work      # proves the stick installs with no network
```

Only one VM may run at a time: the stick is passed through to whichever is up, and
the host cannot use it meanwhile. `vagrant up` unmounts it first; halting or
destroying the VM gives it back.

## Daily use

**Sketching dotfiles.** `just builder`, then `just console`. The kit is installed and
the dotfiles are cloned to `~\code\dotfiles` with the environment variables already
pointing at them, so `komorebic quickstart` writes into the repository. Commit and
`git push` in the VM writes to the stick; on the host, `git pull` in
`~/code/work/dotfiles` picks it up, and you push to GitHub from there.

**Updating.** Nothing updates itself. Everything moves through a commit:

```sh
just outdated
$EDITOR kit/packages.json      # bump "version", and "tag" where it is literal
just lock                      # or: just lock --upgrade
git diff && git commit
just build                     # only changed components rebuild
```

**At work.**

```powershell
powershell -ExecutionPolicy Bypass -File E:\kit\install.ps1
```

Then open a new terminal. Re-run it after every trip with a rebuilt stick; it skips
what is already installed. Changes you make at work go in `~\code\dotfiles`, get
committed, and `git push` sends them to the stick.

## On the stick

```text
USB:\
  repositories\work\dotfiles.git   bare repository, already your origin
  kit\install.ps1 test.ps1 ...     installer, copied from this repository by the build
  kit\dist.json                    kit and dotfiles revisions, plus sha256 of every file
  kit\dist\apps\<name>-<ver>.zip   normalised application trees
  kit\dist\wheels\*.whl            Python wheelhouse
  kit\dist\node-tools.zip          npm tools
  kit\dist\nvim-data.zip           lazy.nvim plugins and compiled parsers
  kit\.cache\                      verified downloads, reused by later builds
```

## Constraints worth knowing

- The machine-wide PATH takes precedence over the user PATH; `test.ps1` warns when
  something there shadows a kit binary.
- Application whitelisting (AppLocker, WDAC) or Constrained Language Mode at work can
  block running binaries or scripts from a user profile. Check
  `$ExecutionContext.SessionState.LanguageMode` before relying on any of this.
- The execution policy must allow unsigned profiles; `install.ps1` warns if it does not.
- A fresh `builder` reinstalls Build Tools (~15 minutes). Prefer `vagrant halt` over
  `destroy`, or bake a box with `../../packer/windows`.
- Windows 11 at work: set `KIT_BOX=gusztavvargadr/windows-11` so the simulator matches.

[docs/design.md](docs/design.md) explains why the pipeline is shaped this way and
records the implementation details that are not obvious from the code.
