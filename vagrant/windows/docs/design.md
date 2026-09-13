# Design

Why the pipeline is shaped this way, and the details that the code does not state
outright.

## Two VMs

`builder` has internet access and Visual Studio Build Tools. It produces the stick.
`work` has neither: its libvirt management network is declared with
`management_network_mode = "none"`, so the template emits no `<forward>` element and
the network is isolated. The host still reaches the guest over the bridge, which is
all WinRM needs, but nothing routes outward. `provision/work.ps1` additionally proves
it by failing if github.com is reachable, because an offline test that quietly ran
online would be worthless.

The work VM is not a convenience: it is the only place where "does this stick work
with no network, no toolchain and no admin" gets answered before you are standing in
the office.

## Stages

`build.ps1` runs these in order, and each is skipped when its inputs are unchanged:

| Component | Input key | Output |
| --- | --- | --- |
| `app:<name>` | the app's entry in `packages.lock.json` | `dist\apps\<name>-<version>.zip` |
| `wheels` | `requirements.txt` + python version | `dist\wheels\*.whl` |
| `node-tools` | `package-lock.json` + node version | `dist\node-tools.zip` |
| `nvim-data` | `lazy-lock.json` + parser list + neovim and tree-sitter versions | `dist\nvim-data.zip` |

Keys are sha256 of those inputs and are recorded in `dist.json` alongside the sha256
of every file the component produced. A rebuild reuses a component when its key
matches and its files are still present; `-Force` rebuilds everything. Files no
component references are deleted at the end, so old versions do not accumulate.

`dist.json` is written last. A build that dies halfway leaves the previous record in
place, and because `install.ps1` verifies checksums before using anything, a partly
written stick is refused rather than half-installed.

The builder installs the apps it just packaged and uses those binaries for the rest of
the build, so the Python that builds the wheels and the Neovim that resolves the
plugins are the ones that ship.

## Unpack online, unzip offline

Applications arrive as zips, MSIs, 7-Zip self-extractors and gzipped binaries. All of
that is dealt with in the builder, where a failure is visible and fixable:

- `.7z.exe` (PortableGit) runs with `-o<dir> -y`, which also runs its post-install step.
- `.msi` (yasb, GlazeWM) is extracted with `msiexec /a`, an administrative install:
  it lays the files out without registering anything or needing elevation. The copy of
  the MSI that lands in the target directory is deleted.
- `.gz` (tree-sitter) is decompressed to the name given by `rename`.
- `.zip` and `.tar.gz` go through `tar.exe`, which ships with Windows and is far
  faster than `Expand-Archive`.

Each tree is then checked against the app's `bin` list and repacked into a normalised
zip. At work, installation is only `tar -xf` plus registry writes, which is the
smallest surface that can fail there.

## Nothing path-sensitive is shipped

The builder and the work laptop have different usernames, so anything containing
absolute paths breaks in transit. That single constraint explains most of the design:

- **Python tools** (`basedpyright` and friends) are *not* built in the VM. Virtual
  environments are not relocatable: `pyvenv.cfg` and the generated `.exe` launchers
  embed the interpreter path. Instead the stick carries a wheelhouse and
  `install.ps1` runs `uv tool install --offline --no-index --find-links`, creating the
  environments on the target machine.
- **Mason is deliberately unused.** It writes absolute paths in its shims and creates
  per-package virtual environments, so a copied `mason` directory breaks under another
  user. Language servers, linters and formatters come from the manifest instead and are
  found on PATH. See [neovim.md](neovim.md).
- **Python itself** is python-build-standalone, which is relocatable and needs no
  installer, so it works without admin rights.
- **Applications** install to `apps\<name>\<version>` with a `current` junction beside
  it. PATH points at `current`, so an upgrade moves a junction and never rewrites PATH.
- **Neovim plugins** are portable: lazy.nvim plugin directories and compiled treesitter
  parsers contain no absolute paths, so they can be built once and copied.

## Configuration without symlinks

Symbolic links need admin rights or Developer Mode; directory junctions need neither,
and neither do user environment variables. So:

- `%LOCALAPPDATA%\nvim` is a junction to `<dotfiles>\nvim`. Neovim's config is the
  repository itself: edits are immediately live and `git status` shows them.
- Everything else is pointed at the dotfiles with user environment variables
  (`KOMOREBI_CONFIG_HOME`, `STARSHIP_CONFIG`, and so on), declared in the manifest.
  Because they are user-level rather than set inside `profile.ps1`, programs started
  outside PowerShell (komorebi, YASB, GlazeWM from the Startup folder) see them too.
- The PowerShell profile gets a one-line stub that dot-sources the profile in the
  dotfiles. An existing profile that the kit did not write is left alone, with a
  warning telling you what to add.

## The USB stick

The stick is found by filesystem label and passed through as a USB device rather than
shared as a folder, so Windows mounts it exactly as it will at work and the same
`install.ps1` runs in both places. `scripts/usb.sh` refuses anything whose udev
properties do not say `ID_BUS=usb`, so a label collision cannot hand an internal disk
to a VM. Passthrough is declared with `startupPolicy='optional'`, letting the VM boot
when the stick is absent.

Before QEMU claims the device, a Vagrant trigger unmounts every partition on it: the
host kernel loses the device the moment the guest takes it, and a mounted filesystem
would lose buffered writes.

Git repositories on removable media trip git's ownership check ("dubious ownership"),
because the stick's files belong to another SID on NTFS and to nobody on exFAT.
`Sync-Dotfiles` therefore registers the bare repository in `safe.directory` before
using it, and re-points `origin` at the current drive letter every run, since the
letter differs between machines.

## Implementation notes

Windows PowerShell 5.1 is what the work laptop has, so the scripts target it:

- Script files stay **pure ASCII**. 5.1 reads a BOM-less file as ANSI, which corrupts
  any non-ASCII character. `just check` enforces this.
- Native commands do not fail a script on a non-zero exit code, hence `Invoke-Native`.
- `Start-Process -PassThru` only exposes `ExitCode` after exit if the handle was
  touched first, hence `$null = $process.Handle`.
- A headless Neovim whose config errors before `+qa` waits forever, so every
  invocation has a timeout, and `nvim-build.lua` always ends in `qa!` or `cq!`.
- `Remove-Item -Recurse` on a junction can delete the *target's* contents in 5.1;
  junctions are removed with `[IO.Directory]::Delete($path, $false)`.
- The user PATH is read and written through the registry with `ExpandString`, to
  preserve `%VARIABLES%` in entries the kit did not write. `[Environment]::
  GetEnvironmentVariable` expands them and `SetEnvironmentVariable` would write back a
  flattened `REG_SZ`.
- A raw registry write does not notify running programs. `SetEnvironmentVariable`
  does broadcast `WM_SETTINGCHANGE`, so `Publish-EnvironmentChange` writes `KIT_ROOT`
  through it after each PATH change, which is what makes Explorer and new terminals
  pick the change up.
- `MyDocuments` is resolved through `[Environment]::GetFolderPath` so that OneDrive
  folder redirection is followed.

## Supply chain

`scripts/lock.sh` resolves each app to an exact URL and sha256, taken from GitHub's
published asset digests, so hashes are pinned in git without hand-copying them. A
release too old to have a digest is downloaded once and hashed locally, with a notice.
Python pins come from `uv pip compile --generate-hashes` resolved for Windows, so the
lock is correct even though it is produced on Linux. Downloads are verified against
the lock in the builder, and the stick is verified against `dist.json` at install
time.

## Known limits

- The machine PATH wins over the user PATH, and changing it needs admin rights.
- Application whitelisting or Constrained Language Mode at work can block this
  approach; nothing here can work around that, by design.
- `npm ci` resolves optional dependencies for the current platform from a lockfile
  generated on Linux. It handles per-platform packages, but a package that only
  publishes a Linux artifact will not appear.
- Wheels are resolved as one dependency set, so two tools with conflicting pins cannot
  both be in `requirements.in`.
- The builder rebuilds `nvim-data` whenever `lazy-lock.json` changes, which is the
  whole file: a one-plugin update re-resolves all of them. It is the safe direction to
  be wrong in.
