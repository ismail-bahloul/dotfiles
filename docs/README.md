# docs

Reference material for this setup, split by purpose.

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
