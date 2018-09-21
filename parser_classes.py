from typing import Tuple

class parser:
  def __init__(self, glob, globtype):
    self.decl_block = globtype
    self.decl_start = ["is"] if globtype in ["entity", "component", "package"] else \
                      ["("] if globtype in ["generic", "port"] else ""
    self.decl_end = ["end"] if globtype in ["entity", "component", "package"] else \
                    ["]"]  if globtype in ["generic", "port"] else ""
    self.glob = get_glob(self, glob)

class Entity:
  def __init__(self, glob):
    self.ports = Ports_generics("ports", glob)
    self.generics = Ports_Generic("generics", glob)

class Ports_generics:
  def __init__(self, glob, globtype):
    self.name, self.typevalues = self.get_entries(self, glob, globtype)


class Typevalue:
  def __init__(self, glob: str) -> None:
    self.datatype, self.range, self.value, self.direc = get_typevalues(glob)
