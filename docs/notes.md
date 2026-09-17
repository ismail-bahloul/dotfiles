# Working notes

Things worth knowing when maintaining this repo or debugging this machine. Not
everything here is interesting to read — this is the stuff that bites.

## Versioned vs non-versioned config

Only the **stable** KDE `.rc` files are versioned (`kwinrulesrc`, `kxkbrc`,
`kglobalshortcutsrc`, `katerc`, `dolphinrc`, `konsolerc`). After a change made
through the UI, run another `chezmoi add`.

`kdeglobals` and `kwinrc` are **deliberately not versioned**: they are rewritten
at runtime (by Plasma, and by `kde-material-you-colors` for the colors), so
versioning them fights the daemon and a `chezmoi apply` would overwrite your
settings. `run_once_08` declaratively imposes the keys that matter instead.

`~/.config/zsh/secrets` is listed in `.chezmoiignore`; it must never be
committed.

## SSH keys

`~/.ssh/id_*` is **not** versioned — back it up manually before a reinstall
(too sensitive to keep in a repo).

## Audio (PipeWire)

Config is versioned in `dot_config/pipewire/` and `dot_config/wireplumber/`:

- **RME Babyface Pro FS** is switchable between **CC** mode (kernel driver,
  `51-rme.conf`) and **proprietary** mode (in-house TuxMix driver via
  `50-tuxmix.conf`) — see `dot_config/pipewire/pipewire.conf.d/README.md`.
- **Per-interface quantum**: global = 64 (RME CC), but the internal Ryzen sound
  card forces 256 (`52-ryzen-quantum.conf`) — 64 causes underruns there.

These quantum and node-name rules are specific to this laptop (Ryzen
`pci-0000_07_00.6`, RME USB) — not portable to other machines.

## Theming

See [`material-you.md`](material-you.md).

## Firmware, power, boot

See [`firmware-limits.md`](firmware-limits.md) and [`boot-tuning.md`](boot-tuning.md).

---

Back to the [main README](../README.md).
