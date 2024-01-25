#!/usr/bin/env python3

#
# This file is part of LiteX-Boards.
#
# Copyright (c) 2020-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import os
import argparse

from migen import *
from migen.genlib.resetsync import AsyncResetSynchronizer

from litex_boards.platforms import ecpix5

from litex.build.lattice.trellis import trellis_args, trellis_argdict

from litex.soc.cores.clock import *
from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *
from litex.soc.cores.led import LedChaser
from litex.soc.cores.video import VideoDVIPHY
from litex.soc.cores.bitbang import I2CMaster

from litedram.modules import MT41K256M16
from litedram.phy import ECP5DDRPHY

from liteeth.phy.ecp5rgmii import LiteEthPHYRGMII

from litex.soc.integration.soc import SoCRegion
from litex.soc.cores.hyperbus import HyperRAM

from litex.soc.interconnect import stream

# CRG ----------------------------------------------------------------------------------------------

class _CRG(Module):
    def __init__(self, platform, sys_clk_freq):
        self.rst = Signal()
        self.clock_domains.cd_init    = ClockDomain("init")
        self.clock_domains.cd_por     = ClockDomain("por",reset_less=True)
        self.clock_domains.cd_sys     = ClockDomain("sys")
        self.clock_domains.cd_sys2x   = ClockDomain("sys2x")
        self.clock_domains.cd_sys2x_i = ClockDomain("sys2x_i",reset_less=True)

        # # #

        self.stop  = Signal()
        self.reset = Signal()

        # Clk / Rst
        clk100 = platform.request("clk100")
        rst_n  = platform.request("rst_n")

        # Power on reset
        por_count = Signal(16, reset=2**16-1)
        por_done  = Signal()
        self.comb += self.cd_por.clk.eq(clk100)
        self.comb += por_done.eq(por_count == 0)
        self.sync.por += If(~por_done, por_count.eq(por_count - 1))

        # PLL
        self.submodules.pll = pll = ECP5PLL()
        self.comb += pll.reset.eq(~por_done | ~rst_n | self.rst)
        pll.register_clkin(clk100, 100e6)
        pll.create_clkout(self.cd_sys2x_i, 2*sys_clk_freq)
        pll.create_clkout(self.cd_init, 25e6)
        self.specials += [
            Instance("ECLKSYNCB",
                i_ECLKI = self.cd_sys2x_i.clk,
                i_STOP  = self.stop,
                o_ECLKO = self.cd_sys2x.clk),
            Instance("CLKDIVF",
                p_DIV     = "2.0",
                i_ALIGNWD = 0,
                i_CLKI    = self.cd_sys2x.clk,
                i_RST     = self.reset,
                o_CDIVX   = self.cd_sys.clk),
            AsyncResetSynchronizer(self.cd_sys,   ~pll.locked | self.reset | self.rst),
            AsyncResetSynchronizer(self.cd_sys2x, ~pll.locked | self.reset | self.rst),
        ]

# from https://github.com/enjoy-digital/litex/blob/master/litex/soc/cores/video.py

from migen.genlib.cdc import MultiReg

hbits = 12
vbits = 12

video_timing_layout = [
    # Synchronization signals.
    ("hsync", 1),
    ("vsync", 1),
    ("de",    1),
    # Extended/Optional synchronization signals.
    ("hres",   hbits),
    ("vres",   vbits),
    ("hcount", hbits),
    ("vcount", vbits),
]

video_data_layout = [
    # Synchronization signals.
    ("hsync", 1),
    ("vsync", 1),
    ("de",    1),
    # Data signals.
    ("r",     8),
    ("g",     8),
    ("b",     8),
]

class SiliceVgaDemo(Module):
    """SiliceVgaDemo"""
    def __init__(self,platform):
        self.enable   = Signal(reset=1)
        self.vtg_sink = vtg_sink = stream.Endpoint(video_timing_layout)
        self.source   = source   = stream.Endpoint(video_data_layout)
        vactive       = Signal(1)
        self.sync += If(vtg_sink.vcount == 0,vactive.eq(1)).Else(
            If(vtg_sink.vcount == vtg_sink.vres,vactive.eq(0)).Else(vactive.eq(vactive))
        )
        self.comb += vtg_sink.connect(source, keep={"valid", "ready", "first", "last", "de", "hsync", "vsync"}),
        # We adapt color depth
        red   = Signal(6)
        green = Signal(6)
        blue  = Signal(6)
        self.comb += source.r.eq(red   << 2)
        self.comb += source.g.eq(green << 2)
        self.comb += source.b.eq(blue  << 2)
        # Add a video demo from Silice
        import silice
        import silice.migen
        f    = silice.Design(
            "../../projects/vga_demo/vga_rototexture.si", # Silice source file
            ["NUM_LEDS=8","color_depth=6"])               # Silice defines
        inst = silice.migen.instantiate(      # + Creates an Instance
            f.getUnit("frame_display"),       # + Silice unit name
            clock      = ClockSignal("sys"),  # + List of IOs bindings
            reset      = ResetSignal("sys"),  #   inputs, outputs, inouts
            run        = Constant(1,1),       #   as named in Silice
            pix_x      = vtg_sink.hcount-1,
            pix_y      = vtg_sink.vcount-1,
            pix_active = vtg_sink.de,
            pix_vblank = ~vactive,
            pix_r      = red,
            pix_g      = green,
            pix_b      = blue,
        )
        self.specials += inst                     # add as an instance
        platform.add_source(inst.verilog_source)  # add verilog source


# BaseSoC ------------------------------------------------------------------------------------------

class BaseSoC(SoCCore):
    def __init__(self, device="85F", sys_clk_freq=int(75e6),
        with_ethernet          = False,
        with_etherbone         = False,
        with_video_terminal    = False,
        with_video_framebuffer = False,
        with_led_chaser        = True,
        **kwargs):
        platform = ecpix5.Platform(device=device, toolchain="trellis")

        # SoCCore ----------------------------------------------------------------------------------
        SoCCore.__init__(self, platform, sys_clk_freq,
            ident = "LiteX SoC on ECPIX-5",
            **kwargs)

        # CRG --------------------------------------------------------------------------------------
        self.submodules.crg = _CRG(platform, sys_clk_freq)

        # DDR3 SDRAM -------------------------------------------------------------------------------
        if True:
          if not self.integrated_main_ram_size:
              pads = platform.request("ddram")
              ddram = ECP5DDRPHY(
                  pads,
                  sys_clk_freq=sys_clk_freq)
              self.submodules.ddrphy = ddram
              self.comb += self.crg.stop.eq(self.ddrphy.init.stop)
              self.comb += self.crg.reset.eq(self.ddrphy.init.reset)
              self.add_sdram("sdram",
                  phy           = self.ddrphy,
                  module        = MT41K256M16(sys_clk_freq, "1:2"),
                  l2_cache_size = kwargs.get("l2_size", 8192)
              )

        # Hyperram ---------------------------------------------------------------------------------
        pads = platform.request("hyperram")
        h = HyperRAM(pads)
        ios = {getattr(pads, a) for a in dir(pads) if not a.startswith('__') and not a == 'name' and not a == 'layout' and not callable(getattr(pads, a))}
        self.submodules.hyperram = h
        self.bus.add_slave("hyperram", slave=self.hyperram.bus, region=SoCRegion(origin=0x60000000, size=8*1024*1024))

        # Ethernet / Etherbone ---------------------------------------------------------------------
        if with_ethernet or with_etherbone:
            self.submodules.ethphy = LiteEthPHYRGMII(
                clock_pads = self.platform.request("eth_clocks"),
                pads       = self.platform.request("eth"),
                rx_delay   = 0e-9)
            if with_ethernet:
                self.add_ethernet(phy=self.ethphy)
            if with_etherbone:
                self.add_etherbone(phy=self.ethphy)

        # HDMI -------------------------------------------------------------------------------------
        if True: # with_video_terminal or with_video_framebuffer:
            # PHY + IT6613 I2C initialization.
            hdmi_pads = platform.request("hdmi")
            self.submodules.videophy = VideoDVIPHY(hdmi_pads, clock_domain="init")
            self.submodules.videoi2c = I2CMaster(hdmi_pads)

            # I2C initialization adapted from https://github.com/ultraembedded/ecpix-5
            # Copyright (c) 2020 https://github.com/ultraembedded
            # Adapted from C to Python.
            REG_TX_SW_RST = 0x04
            B_ENTEST   = (1<<7)
            B_REF_RST  = (1<<5)
            B_AREF_RST = (1<<4)
            B_VID_RST  = (1<<3)
            B_AUD_RST  = (1<<2)
            B_HDMI_RST = (1<<1)
            B_HDCP_RST = (1<<0)

            REG_TX_AFE_DRV_CTRL = 0x61
            B_AFE_DRV_PWD     = (1<<5)
            B_AFE_DRV_RST     = (1<<4)
            B_AFE_DRV_PDRXDET = (1<<2)
            B_AFE_DRV_TERMON  = (1<<1)
            B_AFE_DRV_ENCAL   = (1<<0)

            REG_TX_AFE_XP_CTRL = 0x62
            B_AFE_XP_GAINBIT   = (1<<7)
            B_AFE_XP_PWDPLL    = (1<<6)
            B_AFE_XP_ENI       = (1<<5)
            B_AFE_XP_ER0       = (1<<4)
            B_AFE_XP_RESETB    = (1<<3)
            B_AFE_XP_PWDI      = (1<<2)
            B_AFE_XP_DEI       = (1<<1)
            B_AFE_XP_DER       = (1<<0)

            REG_TX_AFE_ISW_CTRL = 0x63
            B_AFE_RTERM_SEL = (1<<7)
            B_AFE_IP_BYPASS = (1<<6)
            M_AFE_DRV_ISW   = (7<<3)
            O_AFE_DRV_ISW   = 3
            B_AFE_DRV_ISWK  = 7

            REG_TX_AFE_IP_CTRL = 0x64
            B_AFE_IP_GAINBIT = (1<<7)
            B_AFE_IP_PWDPLL  = (1<<6)
            M_AFE_IP_CKSEL   = (3<<4)
            O_AFE_IP_CKSEL   = 4
            B_AFE_IP_ER0     = (1<<3)
            B_AFE_IP_RESETB  = (1<<2)
            B_AFE_IP_ENC     = (1<<1)
            B_AFE_IP_EC1     = (1<<0)

            REG_TX_HDMI_MODE = 0xC0
            B_TX_HDMI_MODE = 1
            B_TX_DVI_MODE  = 0

            REG_TX_GCP = 0xC1
            B_CLR_AVMUTE    = 0
            B_SET_AVMUTE    = 1
            B_TX_SETAVMUTE  = (1<<0)
            B_BLUE_SCR_MUTE = (1<<1)
            B_NODEF_PHASE   = (1<<2)
            B_PHASE_RESYNC  = (1<<3)

            self.videoi2c.add_init(addr=0x4c, init=[
                # Reset.
                (REG_TX_SW_RST, B_REF_RST | B_VID_RST | B_AUD_RST | B_AREF_RST | B_HDCP_RST),
                (REG_TX_SW_RST, 0),

                # Select DVI Mode.
                (REG_TX_HDMI_MODE, B_TX_DVI_MODE),

                # Configure Clks.
                (REG_TX_SW_RST,       B_AUD_RST | B_AREF_RST | B_HDCP_RST),
                (REG_TX_AFE_DRV_CTRL, B_AFE_DRV_RST),
                (REG_TX_AFE_XP_CTRL,  0x18),
                (REG_TX_AFE_ISW_CTRL, 0x10),
                (REG_TX_AFE_IP_CTRL,  0x0C),

                # Enable Clks.
                (REG_TX_AFE_DRV_CTRL, 0),

                # Enable Video.
                (REG_TX_GCP, 0),
            ])
            # Video Terminal/Framebuffer.
            # if with_video_terminal:
            #     self.add_video_terminal(phy=self.videophy, timings="640x480@75Hz", clock_domain="init")
            # if with_video_framebuffer:
            # self.add_video_framebuffer(phy=self.videophy, timings="640x480@75Hz", clock_domain="init")

            # from https://github.com/enjoy-digital/litex/blob/master/litex/soc/integration/soc.py
            from litex.soc.cores.video import VideoTimingGenerator
            vtg = VideoTimingGenerator(default_video_timings="640x480@75Hz")
            vtg = ClockDomainsRenamer("init")(vtg)
            setattr(self.submodules, "vga_demo_vtg", vtg)
            vga_demo = ClockDomainsRenamer("init")(SiliceVgaDemo(platform))
            setattr(self.submodules, "vga_demo", vga_demo)
            self.comb += [
                vtg.source.connect(vga_demo.vtg_sink),
                vga_demo.source.connect(self.videophy if isinstance(self.videophy, stream.Endpoint) else self.videophy.sink)
            ]

        # Leds -------------------------------------------------------------------------------------
        if with_led_chaser:
            leds_pads = []
            for i in range(4):
                rgb_led_pads = platform.request("rgb_led", i)
                self.comb += [getattr(rgb_led_pads, n).eq(1) for n in "gb"] # Disable Green/Blue Leds.
                leds_pads += [getattr(rgb_led_pads, n) for n in "r"]
            self.submodules.leds = LedChaser(
                pads         = Cat(leds_pads),
                sys_clk_freq = sys_clk_freq)

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="LiteX SoC on ECPIX-5")
    parser.add_argument("--build",           action="store_true", help="Build bitstream.")
    parser.add_argument("--load",            action="store_true", help="Load bitstream.")
    parser.add_argument("--flash",           action="store_true", help="Flash bitstream to SPI Flash.")
    parser.add_argument("--device",          default="85F",       help="ECP5 device (45F or 85F).")
    parser.add_argument("--sys-clk-freq",    default=75e6,        help="System clock frequency.")
    parser.add_argument("--with-sdcard",     action="store_true", help="Enable SDCard support.")
    ethopts = parser.add_mutually_exclusive_group()
    ethopts.add_argument("--with-ethernet",  action="store_true", help="Enable Ethernet support.")
    ethopts.add_argument("--with-etherbone", action="store_true", help="Enable Etherbone support.")
    viopts = parser.add_mutually_exclusive_group()
    viopts.add_argument("--with-video-terminal",    action="store_true", help="Enable Video Terminal (HDMI).")
    viopts.add_argument("--with-video-framebuffer", action="store_true", help="Enable Video Framebuffer (HDMI).")

    builder_args(parser)
    soc_core_args(parser)
    trellis_args(parser)
    args = parser.parse_args()

    soc = BaseSoC(
        device                 = args.device,
        sys_clk_freq           = int(float(args.sys_clk_freq)),
        with_ethernet          = args.with_ethernet,
        with_etherbone         = args.with_etherbone,
        with_video_terminal    = args.with_video_terminal,
        with_video_framebuffer = args.with_video_framebuffer,
        **soc_core_argdict(args)
    )
    if args.with_sdcard:
        soc.add_sdcard()
    builder = Builder(soc, **builder_argdict(args))
    builder.build(**trellis_argdict(args), run=args.build)

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(os.path.join(builder.gateware_dir, soc.build_name + ".bit"))

    if args.flash:
        prog = soc.platform.create_programmer()
        prog.flash(None, os.path.join(builder.gateware_dir, soc.build_name + ".bit"))

if __name__ == "__main__":
    main()
