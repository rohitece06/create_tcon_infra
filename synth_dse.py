#!/usr/bin/python3
import os
import toml
import argparse
import parser_classes as PC
import logging
from typing import Union, Tuple
import re
import templates_and_constants as TC


def setloglevel(loglevel: str):
    if loglevel.lower() == "info":
        PC.log.setLevel(logging.INFO)
    if loglevel.lower() == "debug":
        PC.log.setLevel(logging.DEBUG)
    if loglevel.lower() == "warn":
        PC.log.setLevel(logging.WARN)
    if loglevel.lower() == "error":
        PC.log.setLevel(logging.ERROR)
    if loglevel.lower() == "critical":
        PC.log.setLevel(logging.CRITICAL)


def keyword_line(l_no_cmnt: str) -> bool:
    ext_keywords = TC.KEYWORDS + [x+"(" for x in TC.KEYWORDS]
    val = False
    for keyword in ext_keywords:
        if " "+keyword in l_no_cmnt or ":"+keyword in l_no_cmnt:
            val = True
            PC.log.info(f"Not a component instantiation: {l_no_cmnt}")
            break
    return val


def get_direct_deps(entity_path: Union[str, bytes]) -> Tuple[list, list]:
    toml_path = os.path.join(str(entity_path), "RTLenv.toml")
    PC.log.info(f"Gathering dependecies from path {entity_path}")
    parsed_toml = toml.load(toml_path)
    build_deps = parsed_toml['dependencies'].keys()
    test_deps = parsed_toml['test_dependencies'].keys()
    PC.log.info(f"Build dependencies: {build_deps}")
    PC.log.info(f"Test dependencies: {test_deps}\n")
    return list(build_deps), list(test_deps)


class CompDep:
    """Contains an instance's component name, its Entity object, its
    dependencies CompDep object
    """
    def __init__(self, inst: str, src_abs_path: str, qpf_dir: str):
        self.inst = inst
        entity_name = os.path.basename(src_abs_path)
        src_file = f"src/{entity_name}.vhd"
        self.src_abs_path = src_abs_path
        self.src_path = os.path.join(src_abs_path, src_file)
        self.entity = PC.get_entity_from_file(src_abs_path, None)
        self.build_deps, self.test_deps = get_direct_deps(src_abs_path)
        # Create a list of dictionary that contains the instance name, the
        # generic name, and line no where the generic is mapped
        # {"<instance name>": {"comp_name": <name>;
        #  "mapping": {generic name: lineno}}}
        self.map_dict = {}
        self.qpf_dir = os.path.join(src_abs_path, "syn") if qpf_dir is None \
            else qpf_dir
        self.qsf = os.path.join(self.qpf_dir, f"{entity_name}.qsf")
        self.qpf = os.path.join(self.qpf_dir, f"{entity_name}.qpf")
        # Save real paths of dependency entities as used in the quartus project
        # List of dicts: {<entity}
        self.realpaths = {}
        self.rtlenv_path = os.path.join(src_abs_path, "syn/rtlenv")


def get_component_mapping(comp: CompDep):
    """Popiulate the CompDep class object'a map_dict member with all generic
    mapping from each component mapping.
    Refer to the map_dict member comment for the format.

    Arguments:
        comp {CompDep} -- CompDep object
    """
    with open(comp.src_path) as top_f:
        inst_line = 0
        gen_line = 0
        map_line = 0
        paren = 0
        mapping = {}
        inst_name = None
        comp_name = None
        # Note that the lineno are 0-indexed
        for lineno, line in enumerate(top_f):
            # Remove comments
            l_no_cmnt = line.split("--")[0].strip().strip("\n").strip()
            # Make sure that line has a : but no other construct that makes
            # this line a signal/variable/constant declaration
            if l_no_cmnt \
                    and ":" in l_no_cmnt \
                    and ":=" not in l_no_cmnt \
                    and not keyword_line(l_no_cmnt):

                inst_line = lineno
                inst_name = l_no_cmnt.split(":")[0].strip()
                # Potential comp name
                p_cname = l_no_cmnt.split(":")[1].strip()
                if "entity" in p_cname:
                    comp_name = p_cname.split(".")[1].strip()
                else:
                    comp_name = p_cname

            if inst_line > 0:
                PC.log.info(f"Label found at {lineno+1}:: {l_no_cmnt}")
                if (l_no_cmnt and "generic " in l_no_cmnt
                        and " map" in l_no_cmnt):
                    gen_line = lineno
                    PC.log.info(f"generic map found at {lineno+1}:: "
                                f"{l_no_cmnt}")
                if gen_line > 0:
                    # Make sure
                    if "(" in l_no_cmnt and paren == 0:
                        map_line = lineno

                if map_line > 0:
                    gen_split = l_no_cmnt.split("=>")
                    if "(" in gen_split[0] and len(gen_split) > 1:
                        gen_name = gen_split[0].split("(")[1].strip()
                    elif len(gen_split) > 1:
                        gen_name = gen_split[0].strip()
                    else:
                        gen_name = None

                    if gen_name is not None:
                        paren = 1
                        PC.log.info(f"Found mapping at {lineno+1}:: "
                                    f"{l_no_cmnt}")
                        if gen_name not in mapping.keys():
                            PC.log.info(f"Adding {gen_name} map at {lineno}")
                            mapping[gen_name] = lineno
                            gen_name = None
                        else:
                            msg = (f"The instance {inst_name} can not have "
                                   f"two generics of same name: {gen_name} <- "
                                   f"{mapping.keys()}")
                            raise ValueError(msg)


                    # Finish parsing map for this component
                    if (")" in l_no_cmnt and "(" not in l_no_cmnt
                            and map_line != lineno):
                        if inst_name is not None and comp_name is not None:
                            comp.map_dict[inst_name] = {}
                            PC.log.info(f"Found component mapping for "
                                        f"{inst_name}: {mapping}")
                            comp.map_dict[inst_name]["comp_name"] = comp_name
                            comp.map_dict[inst_name]["mapping"] = mapping
                        else:
                            PC.log.error(f"Something went wrong for instance "
                                         f"at {inst_line+1}, {inst_name} "
                                         f"{comp_name}. Please check the "
                                         f"restriction imposed on formats of "
                                         f"supported generic mapping")

                    if "port " in l_no_cmnt and (" map " in l_no_cmnt
                                                 or "map(" in l_no_cmnt):
                        # map_dict = {}
                        mapping = {}
                        inst_name = None
                        comp_name = None
                        gen_name = None
                        gen_line = 0
                        inst_line = 0
                        map_line = 0
                        paren = 0


def get_paths_from_qsf(top_comp: CompDep):
    """Extract path from the qsf for the given entity

    Arguments:


    Returns:
        str -- Path of the file that describes the entity
    """
    # Gather component names
    with open(top_comp.qsf) as q:
        for line in q.readlines():
            for dep, entry in top_comp.map_dict.items():
                if entry["comp_name"].lower() in line and "VHDL_FILE" in line:
                    path = line.split("VHDL_FILE")[1].strip().strip('"')
                    if dep not in top_comp.realpaths.keys():
                        if path.startswith("."):
                            top_comp.realpaths[dep] = \
                                f"{top_comp.src_abs_path}/{path}"
                        else:
                            top_comp.realpaths[dep] = path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="""
        This script generates TCON infrastructure from an entity. This script
        requires the folder structure to be SEL standard RTL folder structure.
        If tb and sim folder does not exist, they will be created. Existing
        folder content will not be overwritten in case of name conflict and
        file names suffixed with seconds since epoch will be created.

        NOTE:: All dependencies must be pull into the component with rtlenv
               before running this script

        Args:
            1)  Full path to the component. Current directory will be used
                if not provided
            2)  Port mapping configuration file, refer to provided example file

        Return:
            1)  Basic tb file with UUT port mapping, SAIF/IRB tcon tb
                component instantiation
            2)  Basic tcon.py, common.py, and pysim.xml """)

    parser.add_argument('-p', '--component_path', type=str, help="Path to the \
                        component's directory. Entity name is \
                        extracted from the path. Default is current directory",
                        default=os.getcwd(), required=False)

    parser.add_argument('-c', '--config_toml', type=str, help="Full path for \
                        generic range configuration file. If not provided, \
                        then top level entity's directory is searched for  \
                        config.toml", required=False)

    parser.add_argument('-l', '--loglevel', type=str, help="Set logging \
                        level: info, debug, warn, error, critical",
                        default="error", required=False)

    parser.add_argument('-q', '--qpf_dir', type=str, help="Give full path of \
                        to the directory where the quartus project file(.qpf) \
                        resides for this build. By default top entity's \
                        syn folder is searched for <entity>.qpf",
                        required=False)

    # !@@@@@@@@@@  Restrictions @@@@@@@@@@
    # !  1) Single line generic maps (i.e. generic map (NAME => NAME, ...)
    # !     In other words, each generic should be mappped in its own line.
    # !     Nothing else should be on that line except comments
    # !  2) Dictionary as entry value in the config toml

    args = parser.parse_args()
    if args.component_path:
        if os.path.isdir(args.component_path):
            top_entity_path = os.path.abspath(args.component_path)
        else:
            top_entity_path = os.path.join(os.path.abspath(os.getcwd()),
                                           args.component_path)
    else:
        top_entity_path = os.path.join(os.getcwd())

    top_entity_path = str(top_entity_path).replace("\\", "/")

    PC.log.info(f"Top entity path is {top_entity_path}")

    top_entity = str(os.path.basename(top_entity_path))
    top_comp = CompDep(inst=top_entity, src_abs_path=top_entity_path,
                       qpf_dir=args.qpf_dir)
    get_component_mapping(top_comp)
    get_paths_from_qsf(top_comp)

    # print(top_comp.map_dict)

    if args.config_toml:
        if args.config.endswith(".toml"):
            config_file = args.config
        else:
            raise ValueError(f"TOML file must have .toml extension")
    else:
        config_file = os.path.join(top_entity_path, "config.toml")

    config_data = toml.load(config_file)
    # print(config_data)

    for inst, gen_vals in config_data.items():
        if inst == "top":
            entity = top_comp.entity
        else:
            filepath = top_comp.realpaths[inst]
            entity = PC.get_entity_from_file(filepath, None)

        setloglevel(args.loglevel)
        for gen_name, val_list in gen_vals.items():
            # the generic value entry will be a dict iff this entry is a
            # hierarchical component with its own generic and value entry
            if type(val_list) != dict:
                if val_list in TC.RSRVD_GEN_VALS and type(val_list) == str:
                    val = [val_list]
                elif type(val_list) == str:
                    val = exec(val_list)
                else:
                    val = val_list if type(val_list) == list else [val_list]
                PC.log.info(f"Using {inst}::{gen_name}={val}")
        # DSE in top-level entity
        setloglevel("error")
