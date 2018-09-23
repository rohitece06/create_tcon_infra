import re
import logging
class ParserType:
  def __init__(self, globtype, glob, name=""):
    """
    Initialize parser class by for certain type by extracting data from
    provide glob
    """
    self.decl_name = name
    self.decl_type = globtype
    self.decl_start = "is" if globtype in ["entity", "component", "package"]\
                      else "(" if globtype in ["generic", "port"]\
                      else ""
    self.decl_end = "end" if globtype in ["entity", "component", "package"]\
                    else ");"  if globtype in ["generic", "port"]\
                    else ""
    self.string = self.get_glob(glob)

  def get_glob(self, glob):
    """
    Get string data for the glob type. For type "entity", it will contain the 
    string for entity declaration. For type "port",  it will contain the 
    string for ports declaration, and so on
    """
    found = ""
    if self.decl_type in ["entity", "component", "package"]:
      start = "{} {} {}".format(self.decl_type, self.decl_name, self.decl_start)
      search_string = '{}(.+?){}'.format(start, self.decl_end)
      try:    
        found = re.search(search_string, glob).group(1)
      except AttributeError:      
        logging.warn(
          "No {} type declaration block found!!!".format(self.decl_type))

    elif self.decl_type in ["generic", "port"]:
      start = "{}{}".format(self.decl_type, self.decl_start)
      false_end = False
      start_collecting = False
      tokens = glob.split()
      # print(tokens, start)
      for token in tokens:
        token_to_add = token
        if token == start:
          start_collecting = True
          token_to_add = ""
        elif token == self.decl_start and start_collecting:
          false_end = True
        elif token == self.decl_end and not false_end and start_collecting:
          break
        elif token == self.decl_end and false_end:
          false_end = False

        if start_collecting:
          found += " "+token_to_add


    # Remove space before ; and (
    no_space_end = re.sub(r'\s+;',';', found)
    no_space_start_end = re.sub(r'\s+\(','(', no_space_end)   
    return no_space_start_end

  # def __str__(self):

class Entity:
  def __init__(self, parserobject):
    self.ports = self.get_entries(parserobject)
    self.generics = self.get_entries(parserobject)
  
  def get_entries(self, parserobject):
    entries = []
    glob = parserobject.string
    definition = None
    for entry in glob.split(";"):
      if parserobject.decl_type == "port":
        definition = Port(entry)
      elif parserobject.decl_type == "generic":
        definition = Generic(entry)
      else:
        logging.error("Wrong parser object type")

      entries.append(definition)

    return entries

class Port:
  def __init__(self, portstring):
    self.name, self.direc, self.dataype, self.range, self.default = \
      self.get_typevalues(portstring)

class Generic:
  def __init__(self, genericstring):
    self.name, self.direc, self.dataype, self.range, self.default = \
      self.get_typevalues(genericstring)
