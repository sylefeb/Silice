from ._silice import *
import tempfile

def check_unit_exists(sf,unit):
  units = sf.listUnits()
  try:
    units.index(unit)
  except ValueError:
    msg = "Cannot find unit '{0}'".format(unit)
    raise ValueError(msg)

def unit_source(sf,unit):
  check_unit_exists(sf,unit)
  v  = sf.write(unit)
  tf = tempfile.NamedTemporaryFile(delete=False,mode="w",suffix=".v")
  tf.write(v)
  return tf.name
