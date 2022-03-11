import migen as mi
from silice import *

def instantiate(unit,params=[],postfix=""):

  inst  = unit.instantiate(params,postfix)

  m     = mi.Module()
  minst = mi.Instance(inst.moduleName())
  m.specials += minst
  m.verilog_source = inst.sourceFile()

  inputs  = unit.listInputs()
  for i in inputs:
    nfo = unit.getVioType(i)
    setattr(m,i,mi.Signal(nfo[1]))
    minst.items.append(mi.Instance.Input("in_{}".format(i),getattr(m,i)))

  outputs = unit.listOutputs()
  for o in outputs:
    nfo = unit.getVioType(o)
    setattr(m,o,mi.Signal(nfo[1]))
    minst.items.append(mi.Instance.Output("out_{}".format(o),getattr(m,o)))

  setattr(m,"clock",mi.Signal(1))
  minst.items.append(mi.Instance.Input("clock".format(o),getattr(m,"clock")))

  setattr(m,"reset",mi.Signal(1))
  minst.items.append(mi.Instance.Input("reset".format(o),getattr(m,"reset")))

  setattr(m,"run",mi.Signal(1))
  minst.items.append(mi.Instance.Input("in_run".format(o),getattr(m,"run")))

  return m
