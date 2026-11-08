# What it writes

| Target | Source |
|---|---|
| `~/.zshrc` | `dot_zshrc` |
| `~/.config/kitty/kitty.conf` | `dot_config/kitty/kitty.conf` |
| `~/.config/gh/config.yml` | `dot_config/gh/config.yml` (`co` alias only) |
| `~/.gitconfig` | `dot_gitconfig`, without the `[user]` identity |
| `~/.local/bin/deploy-plugins` | VST3/LV2/CLAP deployer |

## The two hooks

The machine layer must be able to add to these files without owning them, so
both leave a slot:

| Hook | Provided by | When absent |
|---|---|---|
| `~/.config/zsh/machine.zsh` | sourced at the end of `.zshrc` | nothing sourced |
| `~/.config/kitty/local.conf` | `globinclude` at the end of `kitty.conf` | silently nothing |

`btop` ships no config here: it has no include mechanism, so a wallpaper theme
name has to live *in* the file and the machine layer owns `btop.conf` outright.

## Secrets

None of these are versioned:

- the git identity lives in `~/.config/git/local` (mode 600), pulled in by an
  `[include]` from `~/.gitconfig`. Create it, or `git config user.*` per repo.
- `~/.config/zsh/secrets` (API keys, tokens), sourced by `.zshrc` when present.
- `~/.config/gh/hosts.yml`: `gh auth login` writes its OAuth token there.

## Applying this source beside the machine config

On a host that also has the machine layer, `chezmoi --source
~/.local/share/dotfiles-portable` prints `config file template has changed`.
That is expected: this source has no `chezmoi.toml.tmpl`, so chezmoi compares
the existing machine config against nothing. The apply is exact: `status` is
empty afterwards.

**Do not run `chezmoi init` to "fix" it.** With `--source` pointing here it would
regenerate the machine's `~/.config/chezmoi/chezmoi.toml` from this source and
drop its `components` list.
