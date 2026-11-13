# Install

## One line

```bash
curl -fsSL https://ismailbahloul.com/d | bash
```

That clones this repository into `~/.local/share/dotfiles-portable`, installs
`chezmoi` if it is missing (pacman, apt-get, dnf, zypper or apk), and applies it.

Flags are forwarded with `bash -s --`:

```bash
curl -fsSL https://ismailbahloul.com/d | bash -s -- --dry-run   # plan only
curl -fsSL https://ismailbahloul.com/d | bash -s -- --force     # overwrite
```

`--force` is required when a target already exists with different content: the
list is printed first and nothing is written. Re-running on a host that also has
the machine layer is not such a case: both entry points apply the same clone
(`~/.local/share/dotfiles-portable`), so this one converges to the same files.

## From a clone

```bash
git clone https://github.com/ismail-bahloul/dotfiles.git ~/dotfiles
~/dotfiles/bootstrap.sh
```

The bootstrap notices it is running from a checkout and applies that checkout;
otherwise it clones to `~/.local/share/dotfiles-portable`.

## Packages

Only `chezmoi` is installed for you. The rest is yours to add:

| What | Arch | Fedora | Debian / Mint |
|---|---|---|---|
| shell | `zsh` | `zsh` | `zsh` |
| terminal | `kitty` | `kitty` | `kitty` |
| GitHub CLI | `github-cli` | `gh` | `gh` |

`btop` is not listed on purpose: it has no include mechanism, so its config
belongs to the machine layer (see [config](config.md)).

Make zsh the login shell once, otherwise `~/.zshrc` is never read:

```bash
chsh -s "$(command -v zsh)"
```

Optional, used when present: `zsh-autosuggestions`, `zsh-syntax-highlighting`,
`zsh-history-substring-search`, `fzf`, `zoxide`, and powerlevel10k (Arch:
`zsh-theme-powerlevel10k`; elsewhere clone it into
`~/.local/share/powerlevel10k`). Each missing piece is reported once on stderr, e.g.
`zshrc: zsh-autosuggestions not found (install the distro package)`, rather than
degrading the shell silently.

`~/.p10k.zsh` ships with this layer, so the prompt is the same everywhere. After
re-running `p10k configure`, put the result back in the source with
`chezmoi --source <repo> add ~/.p10k.zsh`.

## Font

`kitty.conf` asks for JetBrains Mono Nerd Font; kitty falls back to its builtin
monospace when the family is absent. Nerd Fonts are not packaged the same way
everywhere, so the only distro-agnostic route is the user font directory:

```bash
mkdir -p ~/.local/share/fonts
# drop JetBrainsMonoNerdFont*.ttf there, then:
fc-cache -f
```

## Updating

```bash
~/dotfiles/bootstrap.sh
```

or, on a machine where this layer was applied by `install.sh`:

```bash
chezmoi --source ~/.local/share/dotfiles-portable apply
```

## Tests

```bash
./test.sh
```

Offline: fake `chezmoi`, `pacman`/`apt-get`, `git` and `sudo`. No network, no
root, nothing written outside a temp dir.
