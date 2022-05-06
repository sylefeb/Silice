import migen as mi
from silice import *
from operator import itemgetter

def instantiate(unit,params=[],postfix="",**kwargs):
  inst    = unit.instantiate(params,postfix)
  minst   = mi.Instance(inst.moduleName())
  inputs  = unit.listInputs()
  inputs.append("run")
  outputs = unit.listOutputs()
  inouts  = unit.listInOuts()
  for k, v in sorted(kwargs.items(), key=itemgetter(0)):
    if k in inputs:
      minst.items.append(mi.Instance.Input("in_{}".format(k), v))
    elif k in outputs:
      minst.items.append(mi.Instance.Output("out_{}".format(k), v))
    elif k in inouts:
      minst.items.append(mi.Instance.InOut("inout_{}".format(k), v))
    else:
      minst.items.append(mi.Instance.Input(k, v))
  minst.verilog_source = inst.sourceFile()
  return minst
