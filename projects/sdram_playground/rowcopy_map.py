#!/usr/bin/env python3

# LLM assisted code
# Reviewed by @sylefeb

"""
rowcopy_map.py  -  Visualize SDRAM rowcopy success across bank 0.

Reads a tiny UART protocol emitted by the Silice/RISC-V firmware
(sdram_ctrl_cpu.si) running bare-metal on the ULX3S:

    RC <rowA_hex> <rowB_hex> <0|1>
    SWEEP

  - "RC a b s"  : tested copying row a (source) -> row b (destination),
                  s = 1 success, 0 failure.
  - "SWEEP"     : marks the start of a fresh full-bank pass (optional;
                  used to auto-save one image per completed sweep).

Builds a heatmap: y = source row, x = destination row, colored by
success (green) / failure (red) / untested (gray). The firmware samples
rows in a fixed step, so the axes are labeled with real row numbers.

INPUT MODES
  --port /dev/ttyUSB0        read live from serial (needs pyserial)
  --file capture.log         replay/parse a saved text log
  (stdin)                    pipe data in:  cat capture.log | rowcopy_map.py

EXAMPLES
  # live, show a window that updates, and save a PNG after each sweep
  python3 rowcopy_map.py --port /dev/ttyUSB0 --baud 9600 --live --save rowcopy.png

  # live, also tee the raw UART into a log so you can re-render later
  python3 rowcopy_map.py --port /dev/ttyUSB0 --log capture.log --save rowcopy.png

  # offline: render a saved log straight to a PNG (no board, no window)
  python3 rowcopy_map.py --file capture.log --save rowcopy.png --no-show
"""

import argparse
import re
import sys
import time

import numpy as np
import matplotlib
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap, BoundaryNorm
from matplotlib.patches import Patch

# RC <hexA> <hexB> <0|1>   (firmware prints 8 hex digits, but accept any width)
RC_RE = re.compile(r"RC\s+([0-9A-Fa-f]+)\s+([0-9A-Fa-f]+)\s+([01])")
SWEEP_RE = re.compile(r"\bSWEEP\b")

# cell states for the grid
UNTESTED = 0
FAILURE = 1
SUCCESS = 2


class RowcopyGrid:
    """Accumulates (src, dst) -> success results and renders a heatmap."""

    def __init__(self):
        self.results = {}          # (src, dst) -> bool
        self.n_lines = 0           # RC lines parsed total
        self.sweeps = 0            # SWEEP markers seen

    def add(self, src, dst, ok):
        self.results[(src, dst)] = ok
        self.n_lines += 1

    def axis_values(self):
        """Sorted unique row numbers seen on either axis."""
        rows = sorted({r for pair in self.results for r in pair})
        return rows

    def to_matrix(self):
        """Return (matrix, rows). matrix[i][j] is state for src=rows[i], dst=rows[j]."""
        rows = self.axis_values()
        idx = {r: i for i, r in enumerate(rows)}
        n = len(rows)
        m = np.full((n, n), UNTESTED, dtype=np.uint8)
        for (src, dst), ok in self.results.items():
            m[idx[src], idx[dst]] = SUCCESS if ok else FAILURE
        return m, rows

    def stats(self):
        tested = len(self.results)
        good = sum(1 for v in self.results.values() if v)
        return tested, good


# tasteful, high-contrast palette that reads well in a LinkedIn screenshot
CMAP = ListedColormap(["#21262d", "#f0506e", "#27d796"])   # untested / fail / success
NORM = BoundaryNorm([-0.5, 0.5, 1.5, 2.5], CMAP.N)


def draw(ax, grid, title="SDRAM rowcopy map  -  bank 0"):
    ax.clear()
    m, rows = grid.to_matrix()
    if m.size == 0:
        ax.text(0.5, 0.5, "waiting for data...", ha="center", va="center",
                color="#8b949e", transform=ax.transAxes, fontsize=14)
        ax.set_axis_off()
        return

    # origin='lower' so row 0 sits at the bottom and numbers climb upward
    ax.imshow(m, cmap=CMAP, norm=NORM, origin="lower", interpolation="nearest",
              aspect="equal")

    n = len(rows)
    # show ~8 ticks max so labels stay readable
    step = max(1, n // 8)
    ticks = list(range(0, n, step))
    ax.set_xticks(ticks)
    ax.set_yticks(ticks)
    ax.set_xticklabels([str(rows[t]) for t in ticks], color="#c9d1d9")
    ax.set_yticklabels([str(rows[t]) for t in ticks], color="#c9d1d9")

    ax.set_xlabel("destination row  (copy target)", color="#c9d1d9", fontsize=11)
    ax.set_ylabel("source row  (copy from)", color="#c9d1d9", fontsize=11)

    tested, good = grid.stats()
    rate = (100.0 * good / tested) if tested else 0.0
    ax.figure.suptitle(title, color="#f0f6fc", fontsize=16, fontweight="bold",
                       x=0.45, y=0.985)
    sub = f"{good}/{tested} pairs copied successfully  ({rate:.1f}%)"
    if grid.sweeps:
        sub += f"   |   sweep #{grid.sweeps}"
    ax.set_title(sub, color="#8b949e", fontsize=10.5, pad=10)

    legend = [
        Patch(facecolor="#27d796", label="copy worked"),
        Patch(facecolor="#f0506e", label="copy failed"),
        Patch(facecolor="#21262d", edgecolor="#30363d", label="not tested"),
    ]
    ax.legend(handles=legend, loc="upper left", bbox_to_anchor=(1.01, 1.0),
              frameon=False, labelcolor="#c9d1d9", fontsize=10)
    ax.tick_params(colors="#8b949e")
    for spine in ax.spines.values():
        spine.set_color("#30363d")


def make_figure():
    plt.style.use("dark_background")
    fig, ax = plt.subplots(figsize=(8.2, 6.6))
    fig.patch.set_facecolor("#0d1117")
    ax.set_facecolor("#0d1117")
    fig.subplots_adjust(left=0.10, right=0.80, top=0.88, bottom=0.10)
    return fig, ax


def save_png(fig, path):
    fig.savefig(path, dpi=160, facecolor=fig.get_facecolor(), bbox_inches="tight")
    print(f"[saved] {path}", file=sys.stderr)


# --------------------------------------------------------------------------
# line sources
# --------------------------------------------------------------------------

def iter_serial_lines(port, baud, logfile=None):
    try:
        import serial
    except ImportError:
        sys.exit("pyserial not installed. Run:  pip install pyserial")
    ser = serial.Serial(port, baud, timeout=1)
    print(f"[serial] {port} @ {baud} baud", file=sys.stderr)
    log = open(logfile, "a", buffering=1) if logfile else None
    buf = b""
    try:
        while True:
            chunk = ser.read(256)
            if not chunk:
                yield None  # idle tick, lets the UI breathe
                continue
            buf += chunk
            while b"\n" in buf:
                raw, buf = buf.split(b"\n", 1)
                line = raw.decode("ascii", "replace").strip("\r\n ")
                if log:
                    log.write(line + "\n")
                yield line
    finally:
        ser.close()
        if log:
            log.close()


def iter_file_lines(path):
    with open(path, "r", errors="replace") as f:
        for line in f:
            yield line.rstrip("\r\n")


def iter_stdin_lines():
    for line in sys.stdin:
        yield line.rstrip("\r\n")


def handle_line(line, grid, save_path, fig):
    """Update grid from one text line. Returns True if a sweep just completed."""
    if line is None:
        return False
    if SWEEP_RE.search(line):
        # a SWEEP marks the boundary of a full pass; save the completed frame
        completed = grid.n_lines > 0
        if completed and save_path:
            save_png(fig, save_path)
        grid.sweeps += 1
        return completed
    m = RC_RE.search(line)
    if m:
        src = int(m.group(1), 16)
        dst = int(m.group(2), 16)
        ok = m.group(3) == "1"
        grid.add(src, dst, ok)
    return False


def main():
    ap = argparse.ArgumentParser(description="Visualize SDRAM rowcopy map (bank 0).")
    src = ap.add_mutually_exclusive_group()
    src.add_argument("--port", help="serial port, e.g. /dev/ttyUSB0 or COM3")
    src.add_argument("--file", help="parse a saved text log instead of serial")
    ap.add_argument("--baud", type=int, default=9600, help="baud rate (default 9600)")
    ap.add_argument("--log", help="while reading serial, also tee raw lines here")
    ap.add_argument("--save", help="PNG path; written per completed sweep / at exit")
    ap.add_argument("--live", action="store_true",
                    help="show a window that updates as data streams in")
    ap.add_argument("--no-show", action="store_true",
                    help="never open a window (offline render)")
    ap.add_argument("--refresh", type=float, default=0.5,
                    help="live redraw interval in seconds (default 0.5)")
    args = ap.parse_args()

    if args.no_show or (not args.live and not args.port):
        matplotlib.use("Agg")

    grid = RowcopyGrid()
    fig, ax = make_figure()

    # pick a line source
    if args.port:
        lines = iter_serial_lines(args.port, args.baud, args.log)
        streaming = True
    elif args.file:
        lines = iter_file_lines(args.file)
        streaming = False
    else:
        if sys.stdin.isatty():
            ap.error("no input: pass --port, --file, or pipe data via stdin")
        lines = iter_stdin_lines()
        streaming = False

    live = args.live and not args.no_show
    if live:
        plt.ion()
        fig.show()

    last_draw = 0.0
    try:
        for line in lines:
            handle_line(line, grid, args.save, fig)
            now = time.time()
            if live and (now - last_draw) >= args.refresh:
                draw(ax, grid)
                fig.canvas.draw_idle()
                fig.canvas.flush_events()
                last_draw = now
    except KeyboardInterrupt:
        print("\n[stopped]", file=sys.stderr)

    # final render
    draw(ax, grid)
    tested, good = grid.stats()
    print(f"[done] {tested} pairs, {good} successful", file=sys.stderr)
    if args.save:
        save_png(fig, args.save)
    if not args.no_show and not streaming:
        if not live:
            plt.show()
    elif live:
        plt.ioff()
        plt.show()


if __name__ == "__main__":
    main()
