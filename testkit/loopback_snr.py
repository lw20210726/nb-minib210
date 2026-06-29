#!/usr/bin/env python3
"""
loopback_snr.py -- RF single-tone loopback data-integrity test for B210 / miniB210 clones.

WHAT IT DOES
  Transmits one clean tone out a TX port and -- via an EXTERNAL, ATTENUATED
  cable into an RX port -- receives it back, then measures the received tone's
  SNR / SFDR / noise-floor by FFT, repeatedly, over time (cold -> hot).

WHY THIS EXISTS (clone boards specifically)
  benchmark_rate proves the digital sample interface keeps *flowing* at rate,
  but it does NOT verify the received sample VALUES are correct. Clone boards
  that keep the AD9361 LVDS-termination resistors while running the CMOS data
  interface (e.g. to stay "LVDS-ready") have slightly eroded data-bus timing
  margin. If that margin ever runs out -- at the highest rate, or as the chip
  heats up -- data bits flip. That shows up HERE as a RISING NOISE FLOOR or
  GROWING SPURS, while benchmark_rate would still happily report 0 errors.

  A clean tone whose SNR/floor stay stable from cold to hot  =>  the data path
  (resistors included) is correct end-to-end at this sample rate.

SAFETY  (read this)
  NEVER connect TX directly to RX. TX output can reach ~+10 dBm; the RX input
  damage threshold is ~-10 dBm. You MUST put a 30-40 dB SMA attenuator in line.

Requires:  python3-uhd, numpy   (sudo apt install python3-uhd python3-numpy)
"""

import argparse
import csv
import sys
import threading
import time

import numpy as np

try:
    import uhd
except ImportError:
    sys.exit("ERROR: python3-uhd not found.  Install it:  sudo apt install python3-uhd")


def make_tone(rate, offset_hz, n=10000, ampl=0.3):
    """Seamless (integer-cycle) tone buffer so the repeated TX block has no seam spur."""
    k = max(1, int(round(offset_hz * n / rate)))
    actual = k * rate / n
    t = np.arange(n)
    tone = (ampl * np.exp(2j * np.pi * k * t / n)).astype(np.complex64)
    return tone.reshape(1, n), actual


def analyze(x, rate, tone_hz, guard=24):
    """Return (tone_dB, floor_dB, SNR_dB, SFDR_dB). Excludes tone, DC/LO-leak and IQ image."""
    n = len(x)
    w = np.hanning(n)
    P = 20.0 * np.log10(np.abs(np.fft.fftshift(np.fft.fft(x * w))) + 1e-12)
    f = np.fft.fftshift(np.fft.fftfreq(n, 1.0 / rate))
    bin_of = lambda hz: int(np.argmin(np.abs(f - hz)))

    c = bin_of(tone_hz)
    lo, hi = max(0, c - 60), min(n, c + 60)
    k = lo + int(np.argmax(P[lo:hi]))            # actual tone peak near expectation
    tone_db = float(P[k])

    mask = np.ones(n, bool)
    for center in (f[k], 0.0, -f[k]):            # tone, DC/LO leakage, IQ image
        b = bin_of(center)
        mask[max(0, b - guard):b + guard] = False
    floor = float(np.median(P[mask]))
    spur = float(np.max(P[mask]))
    return tone_db, floor, tone_db - floor, tone_db - spur


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--args", default="type=b200,fpga=/tmp/libresdr_b210.bin",
                   help="UHD device args (include fpga=... for a custom bin)")
    p.add_argument("--freq", type=float, default=1e9, help="center frequency, Hz")
    p.add_argument("--rate", type=float, default=56e6,
                   help="sample rate, Hz (56e6 = max analog BW; try 61.44e6 to stress the bus hardest)")
    p.add_argument("--tone", type=float, default=5e6, help="tone offset from center, Hz")
    p.add_argument("--tx-gain", type=float, default=30.0)
    p.add_argument("--rx-gain", type=float, default=30.0)
    p.add_argument("--ampl", type=float, default=0.3)
    p.add_argument("--nsamps", type=int, default=1 << 19, help="samples per measurement FFT")
    p.add_argument("--interval", type=float, default=60.0, help="seconds between measurements")
    p.add_argument("--duration", type=float, default=3600.0, help="total seconds (0 = single shot)")
    p.add_argument("--csv", default="loopback_snr.csv")
    p.add_argument("--yes", action="store_true", help="skip the attenuator safety prompt")
    a = p.parse_args()

    print("=" * 72)
    print(" RF single-tone loopback data-integrity test")
    print(" SAFETY: TX -> [30-40 dB ATTENUATOR] -> RX.  NEVER connect TX to RX direct.")
    print("=" * 72)
    if not a.yes:
        if input("Confirm a >=30 dB attenuator is in the TX->RX line [y/N]: ").strip().lower() != "y":
            sys.exit("Aborted. Insert attenuation first.")

    usrp = uhd.usrp.MultiUSRP(a.args)
    usrp.set_tx_rate(a.rate)
    usrp.set_rx_rate(a.rate)
    usrp.set_tx_freq(uhd.types.TuneRequest(a.freq))
    usrp.set_rx_freq(uhd.types.TuneRequest(a.freq))
    usrp.set_tx_gain(a.tx_gain)
    usrp.set_rx_gain(a.rx_gain)

    tone, actual = make_tone(a.rate, a.tone, ampl=a.ampl)
    st = uhd.usrp.StreamArgs("fc32", "sc16")
    st.channels = [0]
    tx_streamer = usrp.get_tx_stream(st)

    running = True

    def tx_worker():
        md = uhd.types.TXMetadata()
        md.has_time_spec = False
        md.start_of_burst = True
        md.end_of_burst = False
        while running:
            try:
                tx_streamer.send(tone, md, 0.1)
            except Exception:
                pass
            md.start_of_burst = False

    th = threading.Thread(target=tx_worker, daemon=True)
    th.start()
    time.sleep(0.5)  # let the TX pipeline prime

    fcsv = open(a.csv, "w", newline="")
    wr = csv.writer(fcsv)
    wr.writerow(["t_s", "tone_db", "floor_db", "snr_db", "sfdr_db", "peak"])

    print("# tone at center%+.3f MHz | rate %g Msps | rx_gain %g | log -> %s"
          % (actual / 1e6, a.rate / 1e6, a.rx_gain, a.csv))
    print("%6s %8s %8s %7s %7s  note" % ("t(s)", "tone", "floor", "SNR", "SFDR"))

    t0 = time.time()
    snrs = []
    try:
        while True:
            samps = usrp.recv_num_samps(a.nsamps, a.freq, a.rate, [0], a.rx_gain)[0]
            peak = float(np.max(np.abs(samps)))
            tone_db, floor, snr, sfdr = analyze(samps, a.rate, actual)
            t = time.time() - t0
            note = ""
            if peak > 0.95:
                note = "CLIP! lower --rx-gain or add attenuation"
            elif snr < 10:
                note = "weak/no tone -- check cable / attenuator / gains"
            else:
                snrs.append(snr)
            wr.writerow(["%.0f" % t, "%.1f" % tone_db, "%.1f" % floor,
                         "%.1f" % snr, "%.1f" % sfdr, "%.2f" % peak])
            fcsv.flush()
            print("%6.0f %8.1f %8.1f %7.1f %7.1f  %s" % (t, tone_db, floor, snr, sfdr, note))
            if a.duration <= 0 or t >= a.duration:
                break
            time.sleep(a.interval)
    except KeyboardInterrupt:
        print("\n(interrupted)")
    finally:
        running = False
        time.sleep(0.3)
        fcsv.close()

    print("\n=== summary ===")
    if snrs:
        s = np.array(snrs)
        drift = s[-1] - s[0]
        spread = s.max() - s.min()
        print("measurements: %d   SNR  min %.1f  max %.1f  cold->hot drift %+.1f dB  spread %.1f dB"
              % (len(s), s.min(), s.max(), drift, spread))
        ok = (spread < 6.0) and (s.min() > 20.0)
        print("verdict (advisory): %s" % ("PASS - tone stable, data path clean"
                                          if ok else "REVIEW - see testkit/README.md criteria"))
        print("CSV saved: %s  (plot snr_db vs t_s to see the cold->hot trend)" % a.csv)
    else:
        print("No valid tone captured. Check the loopback: TX->attenuator->RX, ports, gains.")


if __name__ == "__main__":
    main()
