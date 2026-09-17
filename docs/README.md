# docs

Reference material for this setup, split by purpose.

## What took real work

This is not a "here is my `.zshrc`" repo. The parts that took measurement, each
with a write-up below:

| Area | What it involved |
|---|---|
| **Boot: 114 s → 23 s** | Two dead UEFI boot entries were costing **91 s** of POST; plus an initramfs slimmed 248 → 55 MB and a snapshot cap so the ESP cannot fill up. |
| **Firmware and EC probing** | Mapped the AMD SMU interface on a Ryzen 5800H and established that Curve Optimizer is gated off by HP's firmware on **both** Linux and Windows — including catching a Windows tuning tool that reports failed writes as applied. |
| **VFIO GPU passthrough** | The RTX 3070 bound to `vfio-pci` on demand, a one-shot Limine entry, Looking Glass shared memory, libvirt. |
| **Pro audio on Linux** | Pipewire/JACK with a per-interface quantum (64 for the RME, 256 for the internal Ryzen codec), a switchable proprietary driver mode, and yabridge for Windows VSTs. |
| **Reproducibility** | `chezmoi` plus 11 idempotent `run_once` scripts, and a `validate.sh` that checks the machine actually ended up in the intended state — down to “the NVIDIA modules are still out of the initramfs”. |
| **Debugging** | Root-caused a periodic timer that silently resolved to `infinity`, a libvirt socket loop that undid its own work, and one wrong conclusion of mine that a controlled A/B test overturned. |

## Living reference — start here

These are the current conclusions. If something behaves unexpectedly, these are
what to read.

| Document | What it covers |
|---|---|
| [`firmware-limits.md`](firmware-limits.md) | What the HP firmware and EC allow and forbid: the BIOS power settings, the Curve Optimizer dead end, Sure Start, and what resets an OS-written power profile. |
| [`boot-tuning.md`](boot-tuning.md) | Boot time (114 s → 23 s): what was measured, what was changed, and what is still on the table. |
| [`material-you.md`](material-you.md) | How the wallpaper-driven theming works (kitty / btop / Zed / prompt), the KWin transparency and blur setup, and the two things that break after updates. |

## Investigation record — how we got there

Point-in-time write-ups. They are worth reading for the reasoning, **not** as
current conclusions: they deliberately keep the wrong turns, including one of
mine that a controlled A/B test overturned. Each carries a status note at the top.

| Document | What it is |
|---|---|
| [`HP-OMEN-15-en1xxx-power-report.md`](HP-OMEN-15-en1xxx-power-report.md) | The Linux-side investigation: the SMU interface, BIOS access, and the power-limit behaviour. |
| [`HP-OMEN-CO-verdict-Windows.md`](HP-OMEN-CO-verdict-Windows.md) | The decisive Curve Optimizer verdict, with the evidence gathered from Windows. |
| [`HP-OMEN-LINUX-next-steps.md`](HP-OMEN-LINUX-next-steps.md) | What was left open at the time. Most of it is now closed — the addendum at the end has the outcome. |
| [`evidence/`](evidence/) | Tools and raw data: the SMU prober, the load generator, the benchmark runs, and the nbfc A/B CSVs. |

---

Back to the [main README](../README.md).
