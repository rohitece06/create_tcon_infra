import re
import logging
import os
from collections import OrderedDict
from inspect import currentframe
import templates_and_constants as TC

# Setup logging
log = logging.getLogger() # 'root' Logger

console = logging.StreamHandler()

format_str = '%(levelname)s -- %(filename)s:%(lineno)s -- %(message)s'
console.setFormatter(logging.Formatter(format_str))

log.addHandler(console) # prints to console.

log.setLevel(logging.WARN) # anything ERROR or above


def get_linenumber():
    cf = currentframe()
    return cf.f_back.f_lineno

def get_filestring(filename, parser=None):

    lines_without_comments = ""
    try:
        with open(filename, "r") as f:
            for line in f.readlines():
                lines_without_comments += (line.strip("\n")).split("--")[0]
    except:
        if parser:
            parser.print_help()
            exit()
        else:
            log.error(f"Can't open file {filename}. Exiting...")
            exit()

    filestring = re.sub(r'\s+', ' ', lines_without_comments)
    filestring = filestring.replace(";", "; ")
    filestring = filestring.replace(";  ", "; ")
    return filestring

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

def get_entity_from_file(path, name):
    """Extract entity declaration of TCON master from tb_tcon.vhd

    Args:
        path (str) : os.path type string for entity's source code
        name(str) : name of the tb component whose entity needs to be
                        extracted

    Returns:
        Entity object for the tb component

    """
    if not name:
        entity = os.path.basename(path)
        comppath = f"src/{entity}.vhd"
    elif name != "tb_tcon":
        comppath = f"{name}/src/{name}.vhd"
        entity = name
    else:
        comppath = f"{name}/src/tcon_template.vhd"
        entity = name

    filepath = os.path.join(path, comppath)
    filestring = get_filestring(filepath)
    entity_glob = ParserType("entity", filestring, entity).string
    ports_parser = ParserType("port", entity_glob)
    generics_parser = ParserType("generic", entity_glob)
    entity_inst = Entity(ports_parser, generics_parser)
    return entity_inst

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
        for contype in TC.VHDL_CONSTRUCT_TYPES:
            if globtype in contype["type"]:
                return contype["start_token"], contype["end_token"]
                break
            else:
                continue
        else:
            return None, None
            log.error(f"*{globtype}* VHDL construct type is not supported")

    def get_glob(self, glob):
        """
        Get string data for the glob type. For type "entity", it will contain
        the string for entity declaration. For type "port",  it will contain
        the string for ports declaration, and so on
        """
        found = ""
        # If we are looking for entire entity, component, or pkg declaration
        if self.decl_type in TC.VHDL_BLOCK["type"]:
            start = f"{self.decl_type} {self.decl_name} {self.decl_start}"
            search_string = f'{start}(.+?) {self.decl_end}'
            try:
                found = re.search(search_string, glob).group(1)
            except AttributeError:
                log.warning(
                        f"No *{self.decl_type}* type declaration block found!!!")

            # Remove space before ; and (
            no_space_end = re.sub(r'\s+;', ';', found)
            no_space_start_end = re.sub(r'\s+\(', TC.START_PAREN, no_space_end)

        # If we are looking for interface types such as generics or ports
        elif self.decl_type in TC.VHDL_IF["type"]:
            start = f"{self.decl_type}{self.decl_start}"
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
            no_space_start_end = re.sub(r'\s+\(', TC.START_PAREN, no_space_end)

        # If we are looking for declaration inside the architecture
        elif self.decl_type in TC.VHDL_ARCH["type"]:
            # architecture declaration starts as
            #   architecture xxx of <entity name> is
            start_phrase = \
                    f"{self.decl_type}(.+?)of {self.decl_name} {self.decl_start}"
            # Finds the name of the architecture
            try:
                arch_type = re.search(start_phrase, glob).group(1).strip()
            except AttributeError:
                log.error("Couldn't find name of the architecture")

            start_phrase = \
                f"architecture {arch_type} of {self.decl_name} {self.decl_start}"

            search_string = f'{start_phrase}(.+?){self.decl_end} {arch_type}'
            try:
                arch_string = re.search(search_string, glob).group(1)
            except AttributeError:
                log.error(
                    f"No *{self.decl_type}* type declaration block found")

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


class Entity:
    def __init__(self, portparser, genericparser=None,
                 config_file=TC.BUS_CFG_FILE):
        self.generics = self.get_entries(genericparser) if genericparser else None
        self.ports = self.get_entries(portparser) if portparser else None
        self.port_buses = assign_buses(config_file)

    def get_entries(self, parserobject):
        """Extract entry members of a port or a generic like name of the port,
           direction, data type, range, and default value if any

        Args:
           self: Current object
           parserobject: Parser.ParserType object

        Return:
          list of Port_Generic objects
        """
        entries = []
        if parserobject.decl_type in TC.VHDL_IF["type"]:
            for entry in parserobject.string.split(";"):
                definition = Port_Generic(entry)
                entries.append(definition)
        else:
            log.error("Wrong parser object type")
        return entries

    def __str__(self):
        return f"{str(self.__class__)} : {str(self.__dict__)}"


class Port_Generic:
    def __init__(self, entrystring):
        self.name, self.direc, self.dataype, self.range, self.default = \
                                             self.get_typevalues(entrystring)

    def get_typevalues(self, entrystring):
        """Finds default value provided for a generic or a port.

        Default value is always provide to the right of :=
        We dont care if it is a number or entrystring or a range

        Args:
            entrystring(str) : The line from source code which has an entry for
                               a generic or a port

        Return:
            name(str) : Name of the port or generic
            direc(str) : Direction for the port entry. None for generic entry
            datatype(str) : VHDL Datatype of the port/generic entry
            range(str) : VHDL range of the port/generic entry
            default(str) : Default value, if any, for the port/generic entry

        """
        val_split = entrystring.split(TC.INST_ASSIGN_OP)
        default = val_split[1].strip() if TC.INST_ASSIGN_OP in entrystring \
                  else None
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
        if type_split[0] in TC.VHDL_DIR_TYPE:
            direc = type_split[0].strip()
            datatype = type_split[1].split(TC.START_PAREN)[0].strip()

        else:
            direc = None
            # If there are no direction info, then immediately right to
            # : will be the datatype. remove ( and other character after (
            # from datatype
            datatype = type_split[0].split(TC.START_PAREN)[0].strip()

        # If there is a (...) or "range" keyword present in the entrystring right
        # of : (default value has already been stripped), it must be a range
        # for the datatype
        # "range" always has a pattern of:
        # datatype<space>range<space>N<space>to<space>M
        # Note: 'range will never be used in VHDL-93 compatible entity
        typestring = name_split[1]

        if " range " in typestring:
            range = typestring.split(" range ")[1].strip()
        elif TC.START_PAREN in typestring:
            try:
                range = re.search(r'\((.+?)\)', typestring).group(1)
            except AttributeError:
                logging.warn("No valid vector range found")
                range = None
        else:
            range = None

        logging.info(f"name: {name}, direc: {direc}, datatype: {datatype}, \
                       range: {range}, default:{default}\n")

        return name, direc, datatype, range, default

    def __str__(self):
        return str(self.__class__) + ": " + str(self.__dict__)


class TB:
    def __init__(self, uutpath, uutname):
        self.tb_comp_path = os.path.abspath(os.path.join(uutpath,
                                            TC.TB_SRC_LOCATION))
        self.arch_decl = []
        self.arch_def  = []
        # Entity object for tcon master entity from tb_tcon component diretory in syn\rtlenv
        self.tcon_master = get_entity_from_file(self.tb_comp_path, "tb_tcon")
        self.uut = get_entity_from_file(uutpath, None)
        # List of Entity objects for tb components
        # used by this testbench
        # self.tb_comp = self.get_tb_entities(self.uut) # List of Entity objects

    def get_entity_object(tb_name):
        """
        """


