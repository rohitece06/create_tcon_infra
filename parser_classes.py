import re
import logging
import json
from collections import OrderedDict
from inspect import currentframe

def get_linenumber():
    cf = currentframe()
    return cf.f_back.f_lineno

START_PAREN = "("
END_PAREN = ")"
# Every VHDL block type that defines a component entirely
VHDL_BLOCK = {"type": ["entity", "component", "package"],
              "start_token": "is",
              "end_token": "end"}

# VHDL interface types
VHDL_IF = {"type": ["generic", "port"],
           "start_token": START_PAREN,
           "end_token": ");"}

# BLocks inside VHDL "architecture": Declaration (_DECL) and Definition (_DEF)
#   * Declaration contains signal, function, alias declaration inside the
#     architecture
VHDL_ARCH = {"type": ["architecture"],
             "start_token": "is",
             "end_token": "end"}
VHDL_ARCH_DEF = {"type": ["architecture definition"],
                 "start_token": "begin",
                 "end_token": "end"}
VHDL_PROC = {"type": ["process", "block"],
             "start_token": "begin",
             "end_token": "end"}

VHDL_CONSTRUCT_TYPES = [VHDL_BLOCK, VHDL_IF, VHDL_ARCH, VHDL_PROC]

# VHDL Port direction types
VHDL_DIR_TYPE = ["in", "out", "inout"]
# Instant assignment operator
INST_ASSIGN_OP = ":="
# Signal assignment operator
SIG_ASSIGN_OP = "<="


class ParserType:
    def __init__(self, globtype, glob, name=""):
        """
        Initialize parser class by for certain type by extracting data from
        provide glob
        """
        self.decl_name = name
        self.decl_type = globtype
        self.decl_start, self.decl_end = self.get_start_end_tokens(globtype)
        self.string = self.get_glob(glob)

    def get_start_end_tokens(self, globtype):
        """
        Assign start/end token for each VHDL type. For example, all declaration
        inside an architecture starts after "is" (architecture xxx of <entity>
        is) and ends before "begin". After begin actual code starts.
        """
        for contype in VHDL_CONSTRUCT_TYPES:
            if globtype in contype["type"]:
                return contype["start_token"], contype["end_token"]
                break
            else:
                continue
        else:
            return None, None
            logging.error("*{}* VHDL construct type is not supported".
                          format(globtype))

    def get_glob(self, glob):
        """
        Get string data for the glob type. For type "entity", it will contain
        the string for entity declaration. For type "port",  it will contain
        the string for ports declaration, and so on
        """
        found = ""
        # If we are looking for entire entity, component, or pkg declaration
        if self.decl_type in VHDL_BLOCK["type"]:
            start = "{} {} {}".format(
                self.decl_type, self.decl_name, self.decl_start)
            search_string = '{}(.+?) {}'.format(start, self.decl_end)
            try:
                found = re.search(search_string, glob).group(1)
            except AttributeError:
                logging.warning(
                    "No *{}* type declaration block found!!!".
                    format(self.decl_type))

            # Remove space before ; and (
            no_space_end = re.sub(r'\s+;', ';', found)
            no_space_start_end = re.sub(r'\s+\(', START_PAREN, no_space_end)

        # If we are looking for interface types such as generics or ports
        elif self.decl_type in VHDL_IF["type"]:
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
                elif (token == self.decl_end and not false_end and
                      start_collecting):
                    break
                elif token == self.decl_end and false_end:
                    false_end = False

                if start_collecting:
                    found += " "+token_to_add

            # Remove space before ; and (
            no_space_end = re.sub(r'\s+;', ';', found)
            no_space_start_end = re.sub(r'\s+\(', START_PAREN, no_space_end)

        # If we are looking for declaration inside the architecture
        elif self.decl_type in VHDL_ARCH["type"]:
            # architecture declaration starts as
            #   architecture xxx of <entity name> is
            start_phrase = "{}(.+?)of {} {}".format(self.decl_type,
                                                    self.decl_name,
                                                    self.decl_start)
            # Finds the name of the architecture
            try:
                arch_type = re.search(start_phrase, glob).group(1).strip()
            except AttributeError:
                logging.error("Couldn't find name of the architecture")

            start_phrase = "architecture {} of {} {}".format(arch_type,
                                                             self.decl_name,
                                                             self.decl_start)
            search_string = '{}(.+?){} {}'.format(start_phrase,
                                                  self.decl_end,
                                                  arch_type)
            try:
                arch_string = re.search(search_string, glob).group(1)
            except AttributeError:
                logging.error(
                    "No *{}* type declaration block found".
                    format(self.decl_type))

            # Split architecture glob into declration and definitition globs
            ####################
            # Find declarations
            #################################################################
            # ARCHITECTURE(s) WITH FUNCTION/PROCEDURES IN 'EM ARE
            # NOT SUPPORTED
            #################################################################
            # 'begin' of function/procedure will mess up regex search
            # start_phrase remains the same as before
            arch_split = arch_string.split("begin")
            no_space_start_end = {"arch_decl": arch_split[0].strip(),
                                  "arch_def": ' '.join(arch_split[1:])}

        # If we are looking for definitions (i.e., the actual logic of this
        # component) inside the architecture
        # elif self.decl_type in VHDL_ARCH_DECL["type"]:

        return no_space_start_end


# Use default BUS configurations if user did not provide one
DEFAULT_TCON_TBS =  {"CLK"   : "tb_tcon_clocker",
                     "MISC"   : None,
                     "IRBM"  : "tb_tcon_irb_master",
                     "IRBS"  : "tb_tcon_irb_master",
                     "SAIFM" : "tb_tcon_saif_master",
                     "SAIFS" : "tb_tcon_saif_master",
                     "SDM"   : "tb_tcon_start_done",
                     "SDS"   : "tb_tcon_start_done_slave"}

BUS_CFG_FILE = "BUS_CONFIG.cfg"


def assign_buses(fname):
    bus_cfg = OrderedDict()
    try:
        cfgfile = open(fname, "r")
    except OSError:
        logging.error("open({}) failed".format(fname))
        return None

    prev_bus = None
    with cfgfile:
        for line in cfgfile.readlines():
            entry = line.split(":")
            port = entry[0].strip()
            if port:
                temp = entry[1].strip() if len(entry) > 1 else None
                if (not temp or temp.upper() in ["NONE", "MISC"]):
                    bus = prev_bus if not temp else None

                else:
                    bus = temp.upper()

                if bus not in bus_cfg.keys():
                    bus_cfg[bus] = list()
                bus_cfg[bus].append(port)
                prev_bus = bus
    return bus_cfg

class Entity:
    def __init__(self, portparser, genericparser=None, config_file=BUS_CFG_FILE):
        self.generics = self.get_entries(
            genericparser) if genericparser else None
        self.ports = self.get_entries(portparser) if portparser else None
        self.port_buses = assign_buses(config_file)

    def get_entries(self, parserobject):
        """
          Extract entry members of a port or a generic like name of the port,
          direction, data type, range, and default value if any

          Args:
            self: Current object
            parserobject: Parser.ParserType object

          Return:
            list of Port_Generic objects
        """
        entries = []
        if parserobject.decl_type in VHDL_IF["type"]:
            for entry in parserobject.string.split(";"):
                definition = Port_Generic(entry)
                entries.append(definition)
        else:
            logging.error("Wrong parser object type")
        return entries

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
        val_split = string.split(INST_ASSIGN_OP)
        default = val_split[1].strip() if INST_ASSIGN_OP in string else None
        # Name of the generic/port is always the first word to the left
        # of : symbol in the definition entry
        name_split = val_split[0].split(":")
        name = name_split[0].strip()
        # To the right of :, it is either direction (for port definition)
        # or the datatype for the generic

        type_split = name_split[1].split()

        # there are only three directions in VHDL-93 we use
        # in, out, inout direction, if any, and the datatype are always
        # separated by a space (runs of spaces has already been removed)
        if type_split[0] in VHDL_DIR_TYPE:
            direc = type_split[0].strip()
            datatype = type_split[1].split(START_PAREN)[0].strip()

        else:
            direc = None
            # If there are no direction info, then immediately right to
            # : will be the datatype. remove ( and other character after (
            # from datatype
            datatype = type_split[0].split(START_PAREN)[0].strip()

        # If there is a (...) or "range" keyword present in the string right
        # of : (default value has already been stripped), it must be a range
        # for the datatype
        # "range" always has a pattern of:
        # datatype<space>range<space>N<space>to<space>M
        # Note: 'range will never be used in VHDL-93 compatible entity
        typestring = name_split[1]

        if " range " in typestring:
            range = typestring.split(" range ")[1].strip()
        elif START_PAREN in typestring:
            try:
                range = re.search(r'\((.+?)\)', typestring).group(1)
            except AttributeError:
                logging.warn("No valid vector range found")
                range = None
        else:
            range = None

        logging.info("name: {}, direc: {}, datatype: {}, range: {}, default:\
                    {}\n".format(name, direc, datatype, range, default))

        # print(get_linenumber(), "......", name, direc, datatype, range, default)

        return name, direc, datatype, range, default

    def __str__(self):
        return str(self.__class__) + ": " + str(self.__dict__)

