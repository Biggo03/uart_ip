#!/usr/bin/env bash

# Usage:
#   ./run_fifo.sh <filelist> <testbench> <outdir>
#
# Example:
#   ./run_fifo.sh filelist.f uart_fifo_tb ./sim_out
#
# Requires:
#   - Icarus Verilog (iverilog + vvp)
#

set -e

# ----------------------------
# Argument parsing
# ----------------------------
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <filelist> <tb_file> <outdir>"
    exit 1
fi

FILELIST="$(realpath $1)"
TB_PATH="$(realpath $2)"
OUTDIR="$3"

TB_DIR="$(dirname $TB_PATH)"

mkdir -p "$OUTDIR"

ls -l $FILELIST

# ----------------------------
# Build paths
# ----------------------------
VVP_OUT="$OUTDIR/sim.vvp"
LOG_OUT="$OUTDIR/sim.log"
WAV_OUT="$OUTDIR/sim.vcd"

export PROJ_ROOT=$(realpath ../)

INC_DIRS="-I $PROJ_ROOT/tb -I $TB_DIR"
# ----------------------------
# Compile
# ----------------------------
echo "[INFO] Compiling..."
iverilog -g2012 -o "$VVP_OUT" -D WAVE_PATH=\"$WAV_OUT\" $INC_DIRS "$TB_PATH" -f "$FILELIST"

# ----------------------------
# Run
# ----------------------------
echo "[INFO] Running simulation..."
vvp "$VVP_OUT" | tee "$LOG_OUT"

# ----------------------------
# Wrap-up
# ----------------------------
echo "[INFO] Simulation complete."
echo "[INFO] VCD (if generated): $WAV_OUT"
echo "[INFO] Log: $LOG_OUT"
