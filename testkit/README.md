# miniB210 board test kit

Bring-up / acceptance tests for B210-style boards (genuine **Ettus B210**, **LibreSDR**,
and clones such as **miniB210**). Use these to gain confidence that *your* board
actually works — digitally and over RF — before trusting it.

There are **two independent things to test**, and they are *not* the same:

| Test | Script | Proves | Does **not** prove |
|---|---|---|---|
| Digital stability | `stability_bench.sh` | USB3 / FX3 / FPGA / AD9361 digital interface / clock / power are stable over time & temperature | that the received **sample values** are correct |
| RF data integrity | `loopback_snr.py` | the **whole chain incl. RF** carries correct data at a given rate (cold → hot) | long-term USB stability (run it long if you want both) |

> Why two tests? `benchmark_rate` (used by `stability_bench.sh`) only counts samples and
> packet flow — it **never checks whether the received bits are correct**. So it can report
> `0 errors` even if data bits are occasionally flipping. The RF loopback test is what
> actually verifies data correctness.

### Why clone-board owners should care (the resistor story)

The AD9361 data port is dual-mode: **CMOS** (single-ended) or **LVDS** (differential).
A genuine/clone board laid out for LVDS has **~100 Ω termination resistors** across each
data pair. UHD's B200/B210 driver and the LibreSDR FPGA use the **CMOS** mode, where those
resistors are *not* required.

Many clones (incl. this miniB210) **leave the resistors in place** — deliberately, to keep
the board **LVDS-ready** for a future conversion. In CMOS that is tolerated: each driver
still dominates its own ball (≈1.35 V / 0.45 V across the 100 Ω vs ~50 Ω driver impedance,
both still on the right side of the ~0.9 V threshold). But the resistors **erode timing /
voltage margin**. If margin ever runs out — at the **highest sample rate** (DATA_CLK
fastest) or as the chip **heats up** — bits flip.

`loopback_snr.py` is built to catch exactly that: bit flips show up as a **rising noise
floor** or **growing spurs** in the received tone, even while `benchmark_rate` still says
`0 errors`.

---

## Prerequisites

**Software**
```bash
sudo apt install uhd-host python3-uhd python3-numpy   # Ubuntu/Debian
```
- `uhd-host` provides `benchmark_rate`, `tx_waveform`, `rx_samples_to_file`, …
- `python3-uhd` is the UHD Python API used by `loopback_snr.py`.

**FPGA image** — load your board's `.bin` via the `fpga=` device arg, e.g.
`--args="type=b200,fpga=/tmp/libresdr_b210.bin"`. (Adjust the path in the commands below.)

**Hardware for the RF test only**
- 2× SMA cables and **one 30–40 dB SMA attenuator** (a few dollars — do not skip it).
- Know which SMA on your board is a **TX** port and which is an **RX** port.
  On boards without RF switches (e.g. miniB210) the ports are fixed; they map to UHD's
  `FE-TX1/2` and `FE-RX1/2`.

> ### ⚠ SAFETY — do not skip
> **Never connect TX directly to RX.** TX can reach ~**+10 dBm**; the RX input damage
> threshold is ~**−10 dBm**. You **must** put a **30–40 dB attenuator** in line.
> Target RX input ≈ −30…−20 dBm. No attenuator → do not run the RF test.

---

## 1. Digital stability (no cable needed)

```bash
cd testkit
./stability_bench.sh                          # 1 hour @ 30.72 Msps full-duplex
RATE=16e6 DUR=14400 ./stability_bench.sh       # 4 h, gentler rate
ARGS="type=b200,fpga=/tmp/libresdr_b210.bin" ./stability_bench.sh
```

**Read the summary like this:**
- **Must stay 0** (board health): `sequence errors (Tx/Rx)`, `dropped`, `late commands`, `timeouts`.
- **U / O** (`underruns` / `overruns`) are **host-side flow**:
  - **U** = host fed TX too slowly → device TX buffer emptied.
  - **O** = host read RX too slowly → device RX buffer overflowed.
  - A few are normal (PC / USB load). **Worry only if they climb steadily** over the run.
- Keep the rate within the **USB3 full-duplex budget** (~30 Msps each way ≈ 240 MB/s) so
  U/O stay ~0 and any error that appears is meaningful.

Pass = hard-error counters 0 for the whole run, U/O not trending up.

---

## 2. RF data integrity / SNR trend (needs the attenuated loopback)

Wire it up: **TX port → 30–40 dB attenuator → RX port.**

```bash
cd testkit

# single snapshot first (sanity): one measurement, then exit
./loopback_snr.py --duration 0 \
  --args="type=b200,fpga=/tmp/libresdr_b210.bin" \
  --freq 1e9 --rate 56e6 --tone 5e6 --tx-gain 30 --rx-gain 30

# cold->hot trend: measure once a minute for 2 hours, logs CSV
./loopback_snr.py --duration 7200 --interval 60 \
  --args="type=b200,fpga=/tmp/libresdr_b210.bin" \
  --freq 1e9 --rate 56e6

# stress the data bus hardest (max DATA_CLK):
./loopback_snr.py --rate 61.44e6 ...
```

It prints, per measurement: `tone`, `floor`, `SNR`, `SFDR` (dB) and writes `loopback_snr.csv`.

**Tuning the levels**
- If you see `CLIP!` → lower `--rx-gain` or add attenuation.
- If you see `weak/no tone` → raise `--rx-gain`, check the cable/attenuator/ports.
- Aim for a clear tone with **SNR ≳ 40 dB** that does not clip.

**Interpreting the spectrum (what the numbers mean)**

| Observation | Meaning |
|---|---|
| One clean tone, flat floor, stable over time | ✅ data path (resistors included) is correct at this rate |
| A spike at **DC** and a mirror at **−offset** | ✅ normal AD9361 analog (LO leakage / IQ image) — **not** a data problem (the script already excludes these) |
| **Noise floor rises** / **SNR falls** as the board heats | ⚠ random bit flips — data-bus margin too thin at this rate |
| **New, non-image spurs appear and grow** with time/heat | ⚠ structured bit coupling (e.g. the termination resistors) |

**Verdict (the script prints an advisory one):**
- **PASS** — tone present, **SNR stable cold→hot** (spread < ~6 dB) and healthy (min > ~20 dB).
  → the CMOS data bus carries correct data at this rate *with the resistors in place*.
- **REVIEW** — SNR drifts down / floor climbs / spurs grow over the run.
  → margin is marginal at this rate. Options: run at a lower rate, or (if you need full
  rate) remove the **data-line** termination resistors, or convert the interface to LVDS.

Plot the trend from the CSV:
```bash
python3 - <<'PY'
import csv, matplotlib.pyplot as plt
t,s=[],[]
for r in csv.DictReader(open('loopback_snr.csv')):
    t.append(float(r['t_s'])); s.append(float(r['snr_db']))
plt.plot([x/60 for x in t], s); plt.xlabel('min'); plt.ylabel('SNR dB'); plt.grid(); plt.show()
PY
```

---

## Recommended sequence

1. `./stability_bench.sh` for ≥1 h → confirms thermal/USB/power stability.
2. `loopback_snr.py --duration 0` snapshot → confirms RF actually transmits & receives.
3. `loopback_snr.py --duration 7200` at `56e6` (and optionally `61.44e6`) → confirms data
   integrity holds cold→hot at (near-)max rate.

If all three pass, the board is a fully-functional B210 — digital interface, RF, and data
integrity validated to max rate.

---

*Notes:* tests default to `--args="type=b200,fpga=/tmp/libresdr_b210.bin"` and channel 0;
adjust for your image/path. `benchmark_rate` location differs by distro — the script probes
the common paths (`/usr/lib/uhd/examples`, `/usr/libexec/uhd/examples`, …).
