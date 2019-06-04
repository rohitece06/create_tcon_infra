import re
import logging
import os
import copy
from collections import OrderedDict
from inspect import currentframe
from datetime import datetime
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
    port_list = []
    with cfgfile:
        lines = filter(None, (line.rstrip() for line in cfgfile))
        for line in lines:
            entry = line.strip().split(":")
            port = entry[0].strip()
            pos_bus = entry[1].strip().upper() if len(entry) > 1 else None
            if port:

                if not pos_bus:
                    bus = prev_bus
                elif pos_bus in ["NONE", "MISC"]:
                    bus = None
                    if bus in bus_cfg.keys():
                        port_list = bus_cfg[bus][1]
                    else:
                        port_list = list()
                else:
                    bus = pos_bus
                    port_list = list()

                if bus not in bus_cfg.keys():
                    bus_cfg[bus] = [None, None, None, None]

                port_list.append(port)
                # if bus:
                bus_cfg[bus][1] = port_list
                prev_bus = bus

    # Assign tb file name required for simulating each bus interface whenever
    # applicable. Assign a TCON request ID
    tcon_req_id = 0
    for bus, entry in bus_cfg.items():
        for tb_dep, tb_file in TC.DEFAULT_TCON_TBS.items():
            if bus and bus.upper().startswith(tb_dep):
                tb_entity = tb_file
                break
            else:
                tb_entity = None

        ports = entry[1]
        if ports and bus:
            comp_id = get_instance_name(bus, ports)
        else:
            comp_id = ""

        bus_cfg[bus][0] = tb_entity
        bus_cfg[bus][2] = comp_id
        bus_cfg[bus][3] = tcon_req_id
        if bus:
            tcon_req_id += 1

    return bus_cfg

def get_instance_name(bus, ports):
    """Identify a possible instance prefix name for the TCON tb component. For
    example, if a SAIF slave port has out_rtr port, a tb_tcon_saif component will
    be instantiated with a name "out_saif_master".

    Arguments:
        bus {str} -- A bus name (e.g., CLK, SAIFM, SAIFS, etc)
        ports {list} -- A list of strings that contains ports in the "bus"

    Returns:
        {str} -- Suffix string
    """
    for bus_id, pos_ids in TC.TB_BUS_IDS.items():
        if bus.startswith(bus_id):
            for pos_id in pos_ids:
                for port in ports:
                    if pos_id.lower() in port:
                        temp = port.strip().split(pos_id.lower())[0]
                        prefix = temp if temp else port.strip()
                        if bus_id == "SAIFM":
                            return f"{prefix}_saif_master"
                        elif bus_id == "SAIFS":
                            return f"{prefix}_saif_slave"
                        else:
                            logical_name =\
                                    TC.DEFAULT_TCON_TBS[bus_id].lstrip("tb_tcon")
                            return f"{prefix}{logical_name}"

                    else:
                        return ""

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
    entity_inst = Entity(entity, ports_parser, generics_parser)
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
        # elif self.decl_type in VHDL_arch_decl["type"]:

        return no_space_start_end


class Entity:
    def __init__(self, name, portparser, genericparser=None,
                 config_file=TC.BUS_CFG_FILE):
        self.name = name
        self.generics = self.format_names(self.get_entries(genericparser)) \
                        if genericparser else None
        self.ports = self.format_names(self.get_entries(portparser)) \
                     if portparser else None
        # self.generics = self.get_entries(genericparser) if genericparser else None
        # self.ports = self.get_entries(portparser) if portparser else None
        # Ordered dictionary of ports that are part of a bus. Each bus is supposed
        # to be tested by a TCON compatible testbench component.
        # Dictionary format is :{busname : [list of ports]}
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
                if definition.name.strip():
                    entries.append(definition)
        else:
            log.error("Wrong parser object type")

        return entries

    def format_names(self, entries):
        """Make the generic/port names equal in length by suffixing spaces
        """
        if entries:
            max_len = max([len(entry.name) for entry in entries])
            log.info(f"{max_len}  {self.name}")
            for entry in entries:
                entry.name = entry.name + (max_len-len(entry.name) + 1)*" "
        return entries

    def print_generics(self):
        if self.generics:
            for generic in self.generics:
                generic.print()
        else:
            log.warn(f"No generics exists for entity {self.name}\n")

    def print_ports(self):
        if self.ports:
            for port in self.ports:
                port.print()
        else:
            log.warn(f"No ports exists for entity {self.name}\n")

    def __str__(self):
        return f"{str(self.__class__)} : {str(self.__dict__)}"


class Port_Generic:
    def __init__(self, entrystring):
        self.name, self.direc, self.datatype, self.range, self.default = \
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
        if val_split[0]:
            # Name of the generic/port is always the first word to the left
            # of : symbol in the definition entry
            name_split = val_split[0].split(":")
            name = name_split[0].strip()

            default = val_split[1].strip() if TC.INST_ASSIGN_OP in entrystring else ""

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
                direc = ""
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
                range = "range " + typestring.split(" range ")[1].strip()
                datatype = f"{datatype} "
            elif TC.START_PAREN in typestring:
                try:
                    temp = re.search(r'\((.+?)\)', typestring).group(1)
                    # Add paranthesis back to the range value
                    range = f"({temp})"
                except AttributeError:
                    logging.warn("No valid vector range found")
                    range = ""
            else:
                range = ""

            logging.info(f"name: {name}, direc: {direc}, datatype: {datatype}, \
                        range: {range}, default:{default}\n")

            return name, direc, datatype, range, default
        else:
            return "", "", "", "", ""


    def print(self):
        print(f"'Name': {self.name},    'Direction': {self.direc},    "
              f"'Datatype': {self.datatype},    "
              f"'Range': {self.range},    'Default': {self.default}")

    def __str__(self):
        return str(self.__class__) + ": " + str(self.__dict__)

    def form_signal_entry(self, fill="", add_space=""):
        """Creates entries for a signal declaration
        """
        # if "_vector" not in self.datatype:
        #     datatype = f"{self.datatype} "
        # else:
        #     datatype = self.datatype

        fulldatatype = f"{self.datatype}{self.range}"

        return TC.SIGNAL_ENTRY.format(fill, self.name+add_space, fulldatatype)

    def form_port_entry(self, fill="", add_space="", last=False):
        """Creates entries for a port declaration
        """
        if self.default:
            fulldatatype = f"{self.direc} {self.datatype}{self.range} := {self.default}"
        else:
            fulldatatype = f"{self.direc} {self.datatype}{self.range}"

        if last:
            return TC.PORT_GENERIC_LAST_ENTRY.format(fill, self.name+add_space,
                                                     fulldatatype)
        else:
            return TC.PORT_GENERIC_ENTRY.format(fill, self.name+add_space,
                                                fulldatatype)

    def form_generic_entry(self, fill="", add_space="", last=False,
                           add_defaults=True):
        """Creates entries for a generic declaration
        """
        if self.default and add_defaults:
            fulldatatype = f"{self.datatype}{self.range} := {self.default}"
        else:
            fulldatatype = f"{self.datatype}{self.range}"

        if last:
            return TC.PORT_GENERIC_LAST_ENTRY.format(fill, self.name+add_space,
                                                     fulldatatype)
        else:
            return TC.PORT_GENERIC_ENTRY.format(fill, self.name+add_space,
                                                fulldatatype)

class TB:
    def __init__(self, uutpath, uutname):
        self.tb_comp_path = os.path.abspath(os.path.join(uutpath,
                                            TC.TB_SRC_LOCATION))
        # Entity object for tcon master entity from tb_tcon component diretory in syn\rtlenv
        self.tcon_master = get_entity_from_file(self.tb_comp_path, "tb_tcon")
        self.uut = get_entity_from_file(uutpath, None)
        # List of Entity objects for tb components
        # used by this testbench
        self.tb_dep = self.__get_tb_deps() # List of Entity objects
        self.tb_entity = self.__create_tb_entity()
        self.tb_dep_maps = self.__connect_tb_deps()
        self.arch_decl = list()
        self.arch_def  = list()
        # List that contains already defined signals and constants in the TB
        # architecture
        self.already_defined = list()

    def generate_mapping(self):
        """This function generates mapping for each tb dependency
        """
        self.__connect_tcon_master()
        self.__connect_uut()
        self.__connect_tb_deps()

    def __get_tb_deps(self):
        """Extract Entity type objects for each dependency for the uut

        Args:
            None

        Returns:
            List of Entity objects

        """
        deplist = []
        for tb_dep in self.uut.port_buses.keys():
            if tb_dep:
                def_tb_file = self.uut.port_buses[tb_dep][0]
                deplist.append(get_entity_from_file(self.tb_comp_path,
                                                    def_tb_file))

        return deplist

    def __create_tb_entity(self):
        """Create basic TB entity .

        Args:
            None

        Returns:
            A string that descirbes the entity declaration for the TB

        """
        default_generic = "TEST_PREFIX"
        generic_entry = ""
        if self.uut.generics:
            len_diff = len(default_generic) - len(self.uut.generics[0].name)
            if len_diff <= 0:
                default_generic += " "*(0-len_diff)
                add_space = ""
            else:
                add_space = " "*len_diff

            for generic in self.uut.generics:
                generic_entry += generic.form_generic_entry(
                                                        fill=TC.TB_ENTITY_FILL,
                                                        add_space=add_space, add_defaults=False)

        generic_entry += TC.PORT_GENERIC_LAST_ENTRY.format(TC.TB_ENTITY_FILL,
                                                           default_generic,
                                                           "string")
        return TC.TB_ENTITY.format(self.uut.name, generic_entry, self.uut.name)

    def __connect_tcon_master(self):
        """Create signal definitions and map tcon master entity to signals

        Args:
            None

        Returns:
            1) Updates arch_decl member with full signal declartion required for
               tcon master instantiation
            2) Updates arch_def member with tcon master port mapping
            3) Updates already_listed member with signals that are not already
               declared
        """
        INST_NAME = "tcon_master"
        CMD = '"py -u " & TEST_PREFIX & "/tcon.py"'
        generic_map = list()
        port_map = list()
        generic_map.append(TC.GENERIC_MAP.format(TC.TB_DEP_FILL,
                                                 "INST_NAME   ",
                                                 INST_NAME))
        generic_map.append(TC.GENERIC_MAP_LAST.format(TC.TB_DEP_FILL,
                                                      "COMMAND_LINE",
                                                       CMD))

        decl_hdr = "  -- TCON master signals"
        self.arch_decl.append(decl_hdr + "\n  "+"-"*len(decl_hdr.strip())+"\n")
        for port in self.tcon_master.ports:
            if port.range:
                range = f"({port.range})"
            else:
                if "_gpio" in port.name:
                    range = "(15 downto 0)"
                elif "_vector" in port.datatype:
                    range = "(31 downto 0)"
                else:
                    range = ""

            signal = port.form_signal_entry(fill=TC.TB_ARCH_FILL)
            self.arch_decl.append(signal)
            self.already_defined.append(port.name.strip())

            if port != self.tcon_master.ports[-1]:
                port_map.append(TC.PORT_MAP.format(TC.TB_DEP_FILL, port.name,
                                                   port.name,
                                                   port.direc))
            else:
                port_map.append(TC.PORT_MAP_LAST.format(TC.TB_DEP_FILL, port.name,
                                                        port.name,
                                                        port.direc))
        self.arch_decl.append("\n")
        self.arch_def.append(TC.TB_DEP_MAP_WITH_GENERICS.format(
                                INST_NAME, INST_NAME, self.tcon_master.name,
                                "".join(generic_map), "".join(port_map)))

    def __connect_uut(self):
        """Connect UUT's generics and ports to TB's generic and dedicated
           signals

        Args:
            None

        Returns:
            1) Updates arch_decl member with full signal declartion required for
               UUT instantiation
            2) Updates arch_def member with uut port mapping
            3) Updates already_listed member with signals that are not already
               declared
        """
        decl_hdr = "  -- UUT signals"
        self.arch_decl.append(decl_hdr + "\n  "+"-"*len(decl_hdr.strip())+"\n")

        generic_map= ""
        for generic in self.uut.generics:
            if generic != self.uut.generics[-1]:
                generic_map += TC.GENERIC_MAP.format(TC.TB_DEP_FILL,
                                                       generic.name, generic.name)
            else:
                generic_map += TC.GENERIC_MAP_LAST.format(TC.TB_DEP_FILL,
                                                            generic.name,
                                                            generic.name)
        port_map = ""
        for port in self.uut.ports:
            if port != self.uut.ports[-1]:
                port_map += TC.PORT_MAP.format(TC.TB_DEP_FILL, port.name,
                                                 port.name, port.direc)
            else:
                port_map += TC.PORT_MAP_LAST.format(TC.TB_DEP_FILL, port.name,
                                                      port.name, port.direc)

            if port.name.strip() not in self.already_defined:
                signal_decl = port.form_signal_entry(fill=TC.TB_ARCH_FILL)
                self.arch_decl.append(signal_decl)
                self.already_defined.append(port.name.strip())

        if generic_map:
            uut_map = TC.TB_DEP_MAP_WITH_GENERICS.format(self.uut.name,
                                                            "UUT", self.uut.name,
                                                            generic_map,
                                                            port_map)
        else:
            uut_map = TC.TB_DEP_MAP_WO_GENERICS.format(self.uut.name,
                                                          "UUT", self.uut.name,
                                                          port_map)

        self.arch_def.append(uut_map)

    def __connect_tb_deps(self):
        """Create mapping for each tb dependency

        Arguments:
            None

        Returns:
            Update arch_decl, arch_def, and already_defined class members

        """


