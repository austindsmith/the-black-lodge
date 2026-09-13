# Windows work-laptop simulator

Builds an **offline kit** onto a USB stick: apps, Python wheels, npm tools and a
pre-built Neovim setup that install on a locked-down Windows laptop with **no admin
rights, no network, no Scoop and no GitHub**. The VMs are disposable. Git holds
every input, and the stick holds only derived output plus your dotfiles repo.

Box defaults are `vagrant` / `vagrant`.

```text
 host (Arch)                     builder VM (online, MSVC)            work VM (offline)
 ───────────                     ─────────────────────────            ─────────────────
 kit/packages.json ─ just lock ─> kit/*.lock ── just build ──> USB:\kit\ ── install.ps1 ─> apps, PATH, env
 (what you want)                  (exact URLs,   downloads, verifies,        test.ps1        nvim, wheels,
                                   sha256, pins)  compiles, zips                              dotfiles clone
 ~/code/work/dotfiles ─ git push ─> USB:\repositories\work\dotfiles.git <── git push ── edits in either VM
```

## Pieces

| Where | What |
| --- | --- |
| `kit/packages.json` | The one file you edit: apps (GitHub release + asset), Python tools, treesitter parsers, dotfiles wiring, user env vars. |
| `kit/python/requirements.in`, `kit/node/package.json` | Python and npm packages for the work laptop. |
| `kit/lock.sh` → `packages.lock.json`, `requirements.txt`, `package-lock.json` | Pins everything. App hashes come from GitHub's published asset digests. Commit these. |
| `kit/build.ps1` | Runs in `builder`. Downloads and verifies against the lock, unpacks every installer format (zip, msi, 7z sfx, gz), compiles wheels and parsers, and writes `USB:\kit\`. Incremental: only changed components rebuild. |
| `kit/install.ps1` | Runs from the stick at work (and in both VMs). It only unzips, sets user PATH and env, creates junctions and clones the dotfiles. Re-runnable. |
| `kit/test.ps1` | Offline smoke test: binaries resolve, Neovim loads plugins and parsers, Python tools exist. |
| `Vagrantfile` | `builder` (online, 8 GB, MSVC) and `work` (libvirt network with no forwarding, so truly offline, plus a non-admin `worker` user). |
| `scripts/usb.sh` | Finds the stick by label, refuses non-USB disks, unmounts it before QEMU takes it. |

## The USB stick

Label it `portable` (or set `KIT_USB_LABEL`), formatted exFAT or NTFS. It's found
by label and passed through as a real USB device, so Windows gives it a drive letter
just like at work. **One VM at a time**, and the host loses the stick while a VM owns
it (`vagrant up` unmounts it for you; halt or destroy gives it back).

```text
USB:\
  repositories\work\dotfiles.git   bare repo, your existing origin; the VMs and work clone from it
  kit\install.ps1 test.ps1 ...     installer
  kit\dist.json                    what's on the stick: kit + dotfiles commits, sha256 of every file
  kit\dist\...                     app zips, wheelhouse, node-tools.zip, nvim-data.zip
  kit\.cache\                      download cache so rebuilds in a fresh VM are fast (unused at work)
```

## Workflows

**First run**

```sh
just lock        # already done once; re-run whenever packages.json changes
just builder     # ~20+ min the first time: Build Tools install, then the full kit build
just destroy && just work    # proves the stick installs offline
```

**Sketching dotfiles (komorebi etc.)**: `just builder`, then `just console`. The kit
is installed and your dotfiles are cloned to `~\code\dotfiles`, with the env vars
pointing at them (e.g. `KOMOREBI_CONFIG_HOME`). So `komorebic quickstart`, then edit
`~\code\dotfiles\komorebi\*` live. Commit and `git push` in the VM writes to the
stick. Back on the host, `git pull` in `~/code/work/dotfiles` (origin is the stick),
then push to GitHub as usual.

**Updating (the only way things change)**

```sh
just outdated              # newer upstream releases
$EDITOR kit/packages.json  # bump versions (and literal tags, e.g. git's)
just lock                  # or `just lock --upgrade` to move Python/npm deps too
git diff && git commit     # the review step
just builder / just build  # only changed components rebuild; stale files are pruned
```

Python patch releases, app security fixes and new wheels all arrive this way: bump,
lock, build, carry the stick in, and re-run `install.ps1`. Nothing ever updates
itself.

**At work**

```powershell
powershell -ExecutionPolicy Bypass -File E:\kit\install.ps1
```

New terminal, done. Make changes at work in `~\code\dotfiles`, commit, `git push`.
They reach the host the next time the stick does.

## Neovim: making a config that works offline

`build.ps1` runs your config (`<dotfiles>\nvim\init.lua`) headless in the builder:
`Lazy! restore` from the committed `lazy-lock.json` (plugin `build` steps run there,
with MSVC and cmake on PATH), then compiles the parsers listed in
`packages.json → neovim.treesitter`. The result ships as `nvim-data.zip`, and
`%LOCALAPPDATA%\nvim` is a junction to `<dotfiles>\nvim`. For that to work:

- **Commit `nvim/lazy-lock.json`.** It's what pins plugins. Run `:Lazy update` in the
  builder, then commit the lockfile diff.
- Use **nvim-treesitter's `main` branch** and don't lazy-load it. Enable highlighting
  per filetype with `vim.treesitter.start()`. Never call `install()` at startup.
- **Don't use Mason for the offline setup.** It writes absolute paths (venvs, shims)
  that break under a different username. LSPs, linters and formatters are kit apps
  (`lua-language-server`, `stylua`, `ruff`), uv tools (`basedpyright`) or npm tools
  (`prettier`), all on PATH. `vim.lsp.enable()`, conform and nvim-lint find them there.
- In `lazy.setup`, set `checker = { enabled = false }` and
  `rocks = { enabled = false }` (unless you need luarocks).

## Why it's built this way

- **Unpack online, unzip offline.** MSIs, self-extractors and gz files are handled in
  the builder, where failures are visible. The laptop only runs `tar -xf`, which is
  built into Windows.
- **Nothing absolute-path-sensitive is shipped.** Python tool venvs are created *on*
  the laptop from the wheelhouse (`uv tool install --offline`). Python itself is
  python-build-standalone, which is relocatable. Apps sit at
  `apps\<name>\<version>`, and PATH points at a `current` junction, so upgrades never
  touch PATH.
- **Junctions and user env vars, not symlinks.** Neither needs admin rights or
  Developer Mode. The env vars also fix the old "GlazeWM/YASB don't see profile.ps1
  vars" problem, because they're user-level and not per-shell.
- **Checksums end to end.** The lock pins upstream sha256. `dist.json` pins every
  file on the stick, and install refuses anything corrupt or half-written.

## Known limits

- The **machine** PATH wins over the user PATH. If IT has, say, an old git on it,
  `test.ps1` warns that it shadows the kit's copy.
- If work enforces **AppLocker, WDAC or Constrained Language Mode**, running
  executables or scripts from your profile may be blocked. Check
  `$ExecutionContext.SessionState.LanguageMode` before relying on this.
- The execution policy must allow profiles (`install.ps1` warns). Profile stubs go in
  `profile.ps1`. If `Microsoft.PowerShell_profile.ps1` already dot-sources your
  dotfiles profile, drop that line.
- `builder` reinstalls Build Tools (~15 min) on every fresh VM. Baking a builder box
  with `../../packer/windows` (Build Tools preinstalled) makes that instant. Until
  then, prefer `vagrant halt` to `destroy` for the builder.
- Work on Windows 11? Set `KIT_BOX=gusztavvargadr/windows-11` (with a libvirt
  build) so the simulator matches.
