# docs

Documentation for this repository's own configuration — the "why" behind the
files that ship here.

| Document | What it covers |
|---|---|
| [`boot-tuning.md`](boot-tuning.md) | Boot time (114 s → 23 s): what was measured, what was changed (`run_once_11` + `etc/`), and what is still on the table. |
| [`material-you.md`](material-you.md) | How the wallpaper-driven theming works (kitty / btop / Zed / prompt), the KWin transparency and blur setup, and the two things that break after updates. |
| [`notes.md`](notes.md) | Working notes: which configuration is versioned and which is deliberately not, the PipeWire setup, and SSH keys. |

## Firmware and hardware

The firmware, power and undervolt investigation lives in its own repository:
**[hp-omen-15-en1xxx-firmware](https://github.com/ismail-bahloul/hp-omen-15-en1xxx-firmware)**.

It covers what the BIOS power settings actually do (nothing), why Curve Optimizer
is gated off by HP's firmware on **both** Linux and Windows, and the measured
evidence for each conclusion — including the ones that turned out to be wrong.

---

Back to the [main README](../README.md).
