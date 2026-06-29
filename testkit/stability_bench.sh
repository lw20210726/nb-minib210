#!/usr/bin/env bash
#
# stability_bench.sh -- long-duration DIGITAL stability test (thermal / USB / flow).
#
# Wraps UHD's benchmark_rate to stream RX+TX for a long time and watch for link
# errors as the board heats up. Catches: thermal/USB instability, clock drift,
# intermittent dropouts.
#
# IMPORTANT: this does NOT verify data CORRECTNESS -- benchmark_rate counts
# samples and packet flow, it never checks the sample values. For data
# integrity (the AD9361 CMOS-bus / termination-resistor question) use
# loopback_snr.py instead.
#
# Usage:
#   ./stability_bench.sh                       # 1 h at 30.72 Msps full-duplex
#   RATE=16e6 DUR=7200 ./stability_bench.sh    # override rate / duration (s)
#   ARGS="type=b200,fpga=/path/to.bin" ./stability_bench.sh
#
set -u

ARGS="${ARGS:-type=b200,fpga=/tmp/libresdr_b210.bin}"
RATE="${RATE:-30.72e6}"     # keep within USB3 full-duplex budget (~30 Msps) so U/O ~ 0
DUR="${DUR:-3600}"          # seconds

# benchmark_rate lives in the uhd-host examples dir; location varies by distro.
BR="$(command -v benchmark_rate 2>/dev/null || true)"
for cand in /usr/lib/uhd/examples/benchmark_rate \
            /usr/libexec/uhd/examples/benchmark_rate \
            /usr/local/lib/uhd/examples/benchmark_rate; do
    [ -z "$BR" ] && [ -x "$cand" ] && BR="$cand"
done
if [ -z "${BR:-}" ] || [ ! -x "$BR" ]; then
    echo "ERROR: benchmark_rate not found. Install uhd-host, or set BR=/path/to/benchmark_rate." >&2
    exit 1
fi

echo "benchmark_rate : $BR"
echo "args           : $ARGS"
echo "rate           : $RATE Msps (RX+TX full-duplex)"
echo "duration       : ${DUR}s"
echo
echo "WATCH (board-health, must stay 0): sequence errors, dropped, late, timeouts."
echo "U/O (underrun/overrun) are HOST-side flow indicators -- a few are normal;"
echo "only worry if they climb steadily over time (possible thermal/USB degradation)."
echo

exec "$BR" --args="$ARGS" --rx_rate "$RATE" --tx_rate "$RATE" --duration "$DUR"
