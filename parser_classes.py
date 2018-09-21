from typing import Tuple

class parser:
  def __init__(self, glob, globtype):
    self.decl_block = globtype
    self.decl_start = ["is"] if globtype in ["entity", "component", "package"] else \
                      ["("] if globtype in ["generic", "port"] else ""
    self.decl_end = ["end"] if globtype in ["entity", "component", "package"] else \
                    ["]"]  if globtype in ["generic", "port"] else ""
    self.glob = self.get_glob(glob)

  def get_glob(self, glob: str) -> str:
    glob_data = ""
    return glob_data

class Entity:
  def __init__(self, glob):
    self.ports = Ports_generics("ports", glob)
    self.generics = Ports_generics("generics", glob)

class Ports_generics:
  def __init__(self, glob, globtype):
    self.name, self.typevalues = self.get_entries(glob, globtype)
  
  def get_entries(self, glob: str, globtype: str) -> Tuple:
    name = ""
    typevalues = Typevalue(glob)
    return name, typevalues


class Typevalue:
  def __init__(self, glob: str) -> None:
    self.datatype, self.range, self.value, self.direc = self.get_typevalues(glob)

  def get_typevalues(self, glob: str) -> Tuple:
    datatype = ""
    range = ""
    value = ""
    direc = ""
    return datatype, range, value, direc