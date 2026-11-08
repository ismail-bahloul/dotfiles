# dotfiles — the userspace layer

Zsh, kitty, git, gh and `deploy-plugins`. Works on any Linux: no root beyond the
`chezmoi` package, no system file, no package list, no hardware.

This is the `/d` entry point, and a chezmoi source on its own:

```bash
curl -fsSL https://ismailbahloul.com/d | bash
```

or from a clone:

```bash
~/dotfiles/bootstrap.sh
chezmoi --source ~/.local/share/dotfiles-portable apply
```

The machine layer — drivers, KDE, VFIO, audio, initramfs, udev — lives in the
[machine repository](https://github.com/ismail-bahloul/dotfiles-machine) and is
installed by `/m`. It applies this layer from its own pinned copy, so `/m` alone
leaves a complete machine; `/d` alone leaves a complete userspace.

## What it writes

| Target | Note |
|---|---|
| `~/.zshrc` | sources `~/.config/zsh/machine.zsh` if the machine layer shipped one |
| `~/.config/kitty/kitty.conf` | `globinclude local.conf` at the end (silent when absent) |
| `~/.config/gh/config.yml` | `co` alias; `hosts.yml` is local (OAuth token) |
| `~/.gitconfig` | no `[user]` identity, see below |
| `~/.local/bin/deploy-plugins` | VST3/LV2/CLAP deployer |

`~/.config/zsh/machine.zsh` and `~/.config/kitty/local.conf` are **hooks**: the
machine layer fills them, and nothing breaks when it does not.

## Packages — nothing is installed for you

| What | Arch | Fedora | Debian / Mint |
|---|---|---|---|
| shell | `zsh` | `zsh` | `zsh` |
| terminal | `kitty` | `kitty` | `kitty` |
| monitor | `btop` | `btop` | `btop` |
| GitHub CLI | `github-cli` | `gh` | `gh` |

Optional, used when present: `zsh-autosuggestions`, `zsh-syntax-highlighting`,
`zsh-history-substring-search`, `fzf`, `zoxide`, and powerlevel10k (Arch:
`zsh-theme-powerlevel10k`; elsewhere clone it into
`~/.local/share/powerlevel10k`). Each missing piece is reported once on stderr —
`zshrc: zsh-autosuggestions not found (install the distro package)` — rather
than degrading the shell silently.

btop ships **no config** here: btop has no include mechanism, so a wallpaper
theme name has to live in the file, and the machine layer owns it outright.

## Font

`kitty.conf` asks for JetBrains Mono Nerd Font; kitty falls back to its builtin
monospace when the family is absent. Nerd Fonts are not packaged the same way
everywhere, so the only distro-agnostic route is the user font directory:

```bash
mkdir -p ~/.local/share/fonts
# drop JetBrainsMonoNerdFont*.ttf there, then:
fc-cache -f
```

## Secrets

Neither the git identity (`~/.config/git/local`, pulled in by an `[include]`)
nor `~/.config/zsh/secrets` is versioned; `gh auth login` writes its own token
to `~/.config/gh/hosts.yml`.

## Tests

```bash
./test.sh
```

Offline: fake `chezmoi`, `pacman`/`apt-get`, `git` and `sudo`. No network, no
root, nothing written outside a temp dir.
