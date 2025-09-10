#!/usr/bin/env python3

#
# This file is part of LiteX-Boards.
#
# Copyright (c) 2019 Sean Cross <sean@xobs.io>
# Copyright (c) 2018 David Shah <dave@ds0.me>
# Copyright (c) 2020 Piotr Esden-Tempski <piotr@esden.net>
# Copyright (c) 2020 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

# The iCEBreaker is the first open source iCE40 FPGA development board designed for teachers and
# students: https://www.crowdsupply.com/1bitsquared/icebreaker-fpga

# This target file provides a minimal LiteX SoC for the iCEBreaker with a CPU, its ROM (in SPI Flash),
# its SRAM, close to the others LiteX targets. A more complete example of LiteX SoC for the iCEBreaker
# with more features, examples to run C/Rust code on the RISC-V CPU and documentation can be found
# at: https://github.com/icebreaker-fpga/icebreaker-litex-examples

#
# Heavily modified by @sylefeb for python Silice demo
#

import argparse

from migen import *
from migen.genlib.resetsync import AsyncResetSynchronizer

from litex_boards.platforms import icebreaker

from litex.soc.cores.clock import iCE40PLL
from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *
from litex.soc.cores.video import VideoDVIPHY

# CRG ----------------------------------------------------------------------------------------------

class _CRG(Module):
    def __init__(self, platform, sys_clk_freq):
        self.rst = Signal()
        self.clock_domains.cd_sys = ClockDomain("sys")
        self.clock_domains.cd_por = ClockDomain("por",reset_less=True)

        # # #

        # Clk/Rst
        clk12 = platform.request("clk12")
        rst_n = platform.request("user_btn_n")

        # Power On Reset
        por_count = Signal(16, reset=2**16-1)
        por_done  = Signal()
        self.comb += self.cd_por.clk.eq(ClockSignal())
        self.comb += por_done.eq(por_count == 0)
        self.sync.por += If(~por_done, por_count.eq(por_count - 1))

        # PLL
        self.submodules.pll = pll = iCE40PLL(primitive="SB_PLL40_PAD")
        self.comb += pll.reset.eq(~rst_n) # FIXME: Add proper iCE40PLL reset support and add back | self.rst.
        pll.register_clkin(clk12, 12e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq, with_reset=False)
        self.specials += AsyncResetSynchronizer(self.cd_sys, ~por_done | ~pll.locked)
        platform.add_period_constraint(self.cd_sys.clk, 1e9/sys_clk_freq)

# Design ------------------------------------------------------------------------------------------

class Design(Module):
    def __init__(self,
                 platform,
                 sys_clk_freq,
                 **kwargs):

        # CRG
        crg = _CRG(platform, sys_clk_freq)
        self.submodules.crg = crg

        # Video
        platform.add_extension(icebreaker.dvi_pmod)
        self.submodules.videophy = VideoDVIPHY(platform.request("dvi"), clock_domain="sys")

        # Add a blinker from Silice
        import silice
        import silice.migen

        d = silice.Design("../../projects/blinky/blinky.si",
                         ["NUM_LEDS=5"])
        m = d.getUnit("main")
        leds = platform.request_all("user_led")
        inst = silice.migen.instantiate(
            m,
            clock = ClockSignal("sys"),
            reset = ResetSignal("sys"),
            leds  = leds
        )
        self.specials += inst
        platform.add_source(inst.verilog_source)


# Build --------------------------------------------------------------------------------------------

def main():

    parser = argparse.ArgumentParser()
    soc_core_args(parser)
    args = parser.parse_args()

    platform = icebreaker.Platform()
    platform.add_extension(icebreaker.break_off_pmod)

    soc = Design(
        platform,
        sys_clk_freq = int(float(25e6)),
        **soc_core_argdict(args)
    )

    soc.finalize()

    platform.build(soc)

    prog = platform.create_programmer()
    prog.load_bitstream("build/top.bin")

if __name__ == "__main__":
    main()
