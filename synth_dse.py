#!/usr/bin/python3
import os
import toml
import argparse
import parser_classes as PC
import logging
from typing import Union, Tuple


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


def get_direct_deps(entity_path: Union[str, bytes]) -> Tuple[list, list]:
    toml_path = os.path.join(str(entity_path), "RTLenv.toml")
    print("")
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
    def __init__(self, inst: str, src_abs_path: str):
        self.inst = inst
        entity = os.path.basename(src_abs_path)
        src_file = f"/src/{entity}.vhd"
        self.src_path = os.path.join(src_file, src_abs_path)
        self.entity = PC.get_entity_from_file(self.src_path, None)
        self.build_deps, self.test_deps = get_direct_deps(src_abs_path)

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

    parser.add_argument('-p', '--component_path', type=str, help="Path to the\
                        component's directory. Entity name is \
                        extracted from the path. Default is current directory",
                        default=os.getcwd(), required=False)

    parser.add_argument('-c', '--config', type=str, help="Full path for\
                        bus configuration file", required=False)

    parser.add_argument('-l', '--loglevel', type=str, help="Set logging level: \
                        info, debug, warn, error, critical", default="error",
                        required=False)

    args = parser.parse_args()
    setloglevel(args.loglevel)
    if args.component_path:
        if os.path.isdir(args.component_path):
            top_entity_path = os.path.abspath(args.component_path)
        else:
            top_entity_path = os.path.join(os.path.abspath(os.getcwd()),
                                           args.component_path)
    else:
        top_entity_path = os.path.join(os.getcwd())
    top_entity_path = str(top_entity_path).replace("\\", "/")
    top_rtlenv_dir  = f"{top_entity_path}/syn/rtlenv/"
    PC.log.info(f"Top entity path is {top_entity_path}")

    top_entity = str(os.path.basename(top_entity_path))
    top_comp = CompDep(inst=top_entity, src_abs_path=top_entity_path)
    for x in top_comp.entity.generics:
        print(x)