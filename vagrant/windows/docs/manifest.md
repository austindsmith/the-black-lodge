# The manifest

`kit/packages.json` is the only file you edit by hand. `just lock` turns it into
`kit/packages.lock.json`, which the builder consumes. `just check` validates both.

## Top level

| Key | Meaning |
| --- | --- |
| `schema` | Manifest format version. Currently `1`. |
| `root` | Where the kit installs on the target, e.g. `{localappdata}\\kit`. |
| `apps` | Applications, in install order. |
| `python.tools` | Packages installed as command-line tools by `uv tool install`. Each must also appear in `python/requirements.in`. |
| `neovim.treesitter` | Parsers to compile in the builder. |
| `dotfiles` | Where the dotfiles come from and how they are wired up. |
| `env` | User environment variables to set on the target. |

Placeholders usable in `root`, `dotfiles` and `env`: `{home}`, `{localappdata}`,
`{appdata}`, `{root}`, `{dotfiles}`. Paths use escaped backslashes.

## Applications

```json
{
  "name": "neovim",
  "repo": "neovim/neovim",
  "version": "0.12.5",
  "asset": "nvim-win64.zip",
  "extract_dir": "nvim-win64",
  "path": ["bin"],
  "bin": ["bin\\nvim.exe"]
}
```

| Field | Required | Meaning |
| --- | --- | --- |
| `name` | yes | Install directory name, and how other parts of the kit refer to it. |
| `version` | yes | Upstream version. Bumping this is how updates happen. |
| `repo` | with `asset` | GitHub `owner/name`; the release asset supplies the url and sha256. |
| `asset` | with `repo` | Exact asset file name. |
| `tag` | no | Release tag. Defaults to `v{version}`. Set it literally when upstream tags differ, as git-for-windows does. |
| `url` + `sha256` | instead of `repo` | For downloads that are not GitHub releases, such as nodejs.org. Both must be updated together. |
| `extract_dir` | no | Subdirectory inside the archive that becomes the application root. |
| `rename` | for single files | File name to save a bare `.exe` or `.gz` download as. |
| `path` | no | Directories added to PATH, relative to the application root. Defaults to `["."]`. |
| `bin` | no | Files that must exist after unpacking. The build fails with a listing of what it actually found, which is how a wrong `extract_dir` is caught in the builder rather than at work. |

`{version}` and `{tag}` are substituted in `asset`, `url` and `extract_dir`.

### Reserved names

Other parts of the build look these up by name: `python` (interpreter for the
wheelhouse and for `uv tool install`), `node` (runs `npm ci`), `neovim` and
`tree-sitter` (build the Neovim bundle), `git` (clones the dotfiles). `just check`
requires `git`, `neovim` and `python`.

### Supported download formats

`.zip`, `.tar.gz`/`.tgz`, `.msi` (extracted with an administrative install), `.7z.exe`
(self-extractor), `.gz` and a bare `.exe` (both need `rename`). Anything else fails the
build with a clear message; add a rule to `Expand-AppArchive` in `kit/build.ps1`.

## Dotfiles

```json
"dotfiles": {
  "repo": "repositories\\work\\dotfiles.git",
  "path": "{home}\\code\\dotfiles",
  "junctions": { "{localappdata}\\nvim": "{dotfiles}\\nvim" },
  "profile": "{dotfiles}\\powershell\\profile.ps1"
}
```

`repo` is relative to the root of the stick and must be a bare repository; the install
clones it to `path`, or fast-forwards an existing clone, and points `origin` at the
stick. `junctions` link directories that a program insists on finding at a fixed
location. `profile` is dot-sourced from a generated PowerShell profile stub.

Anything a program can be pointed at with an environment variable belongs in `env`
instead of `junctions`.

## Adding an application

1. Find the release asset name: `gh release view --repo <owner>/<name> --json assets`.
2. Add an entry. Set `extract_dir` if the archive has a top-level folder, and list the
   binaries you expect in `bin`.
3. `just lock` resolves the url and hash, `just check` validates the result.
4. `git commit`, then `just build`.

If `bin` does not match after unpacking, the builder prints the executables it found,
which is usually enough to correct `extract_dir` or `bin` in one pass.

## Updating

`just outdated` compares each locked tag with the latest upstream release. Bump
`version` in the manifest (and `tag` where it is literal), then `just lock`. For
Python and npm dependencies, `just lock --upgrade` moves them within the ranges in
`requirements.in` and `node/package.json`. Review with `git diff` and commit: that diff
is the record of what changed on the stick.

## Lock files

`packages.lock.json` is the manifest with `{version}`/`{tag}` resolved and a `url` plus
`sha256` added per app. `requirements.txt` is a fully resolved, hash-pinned set for
Windows on the manifest's Python version. `package-lock.json` is a standard npm
lockfile. All three are generated; edit the inputs and re-lock instead.
