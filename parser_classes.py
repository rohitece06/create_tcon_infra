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

class Entity:
  def __init__(self, portparser, genericparser="", config=""):
    self.ports = self.get_entries(portparser)
    self.generics = self.get_entries(genericparser) if genericparser else ""
    self.bustype = self.get_bus_type(config)
  
  def get_entries(self, parserobject):
    """
      Extract entry members of a port or a generic like name of the port, direction,
      data type, range, and default value if any
    """
    entries = []
    if parserobject.decl_type in ["port", "generic"]:
      for entry in parserobject.string.split(";"):      
        definition = Port_Generic(entry)
        entries.append(definition)
    else:
        logging.error("Wrong parser object type")

    return entries


  def get_bus_type(self, config):
    """
      Assign bus types of each port, based on a default or supplied json config 
    """
    return 
    

  def __str__(self):
      return str(self.__class__) + ": " + str(self.__dict__)    

class Port_Generic:
  def __init__(self, entrystring):
    self.name, self.direc, self.dataype, self.range, self.default = \
      self.get_typevalues(entrystring)

  def get_typevalues(self, string):
    # Find default value provided for a generic or a port.
    # Default value is always provide to the right of :=
    # We dont care if it is a number or string or whatver
    val_split = string.split(":=")
    default = val_split[1].strip() if ":=" in string else ""
    # Name of the generic/port is always the first word to the left 
    # of : symbol in the definition entry
    name_split = val_split[0].split(":")
    name = name_split[0].strip()
    # To the right of :, it is either direction (for port definition)
    # or the datatype for the generic
    type_split = name_split[1].split()

    # there are only three directions in VHDL-93 we use
    # in, out, inout
    # direction, if any, and the datatype are always separated by
    # a space (runs of spaces has already been removed)
    if type_split[0] in ["in", "out", "inout"]:
      direc = type_split[0].strip()
      datatype = type_split[1].split("(")[0].strip()
      
    else:
      direc = ""
      # If there are no direction info, then immediately right to
      # : will be the datatype. remove ( and other character after (
      # from datatype 
      datatype = type_split[0].split("(")[0].strip()
      

    # If there is a (...) or "range" keyword present in the string right 
    # of : (default value has already been stripped), it must be a range 
    # for the datatype
    # "range" always has a pattern of:
    # datatype<space>range<space>N<space>to<space>M
    typestring = name_split[1]
    
    if " range " in typestring:
      range = typestring.split(" range ")[1].strip()
    elif "(" in typestring:
      try:
        range = re.search(r'\((.+?)\)', typestring).group(1) 
      except AttributeError:
        logging.warn("No valid vector range found")
        range = ""
    else:
      range = ""

    print("name:{}, direc:{}, datatype:{}, range:{}, default:{}\n".format(name, direc, datatype, range, default))
    return name, direc, datatype, range, default

  def __str__(self):
    return str(self.__class__) + ": " + str(self.__dict__)