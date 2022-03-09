from migen import *
from migen.fhdl.tools import *
from migen.fhdl.namer import build_namespace
from migen.fhdl.conv_output import ConvOutput
from migen.fhdl.verilog import convert

from ._silice import compile as _compile

class Dummy(Module):
    def __init__(self):
        self.s = Signal(2)
        self.comb += self.s.eq(16)

class FakeModule(Module):
    pass

def compile(src):
    # d = Dummy()
    # r = convert(d)
    # r.write("d.v")

    d = FakeModule()
    d.s = Signal(2)
    print(d)
    sigs = {getattr(d, a) for a in dir(d) if not a.startswith('__') and not a == 'name' and not a == 'layout' and not callable(getattr(d, a))}
    print(sigs)
    ns = build_namespace(
        signals = (sigs)
    )
    for signal in sigs:
        ns.get_name(signal)
    v = _compile(src)
    r = ConvOutput()
    r.set_main_source(v)
    r.ns = ns
    print(r.ns.sigs)
    return r
