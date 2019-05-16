#!/usr/bin/python3
import re
import os
import time
import argparse
import sys
import parser_classes as PARSER
from inspect import currentframe

def get_linenumber():
    cf = currentframe()
    return cf.f_back.f_lineno


def get_tb_file(comppath):
    compname = os.path.basename(comppath)
    tb_file = os.path.join(comppath, "tb/{}_tb/src/{}_tb.vhd".
                           format(compname, compname))
    if os.path.isfile(tb_file):
        tb_file = os.path.join(comppath, "tb/{}_tb/src/{}_tb_{}.vhd".
                               format(compname, compname, time.time()))
    return tb_file

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="""
        This script generates TCON infrastructure from an entity. This script
        requires the folder structure to be SEL standard RTL folder structure.
        If tb and sim folder does not exist, they will be created. Existing
        folder content will not be overwritten in case of name conflict and
        file names suffixed with seconds since epoch will be created.

        Args:
            1)  Full path to the component. Current directory will be used
                if not provided
            2)  Port mapping configuration file, refer to provided example file

        Return:
            1)  Basic tb file with UUT port mapping, SAIF/IRB tcon tb
                component instantiation
            2)  Basic tcon.py, common.py, and pysim.xml """)

    parser.add_argument('-p', '--component-path', type=str, help="Path to the\
                        component's directory. Entity name is \
                        extracted from the path. Default is current directory",
                        default=os.getcwd(), required=False)

    parser.add_argument('-j', '--config-json', type=str, help="Full path for\
                        json configuration file", required=False)

    args = parser.parse_args()
    uutpath = os.path.abspath(os.path.join(args.component_path))
    uutname = os.path.basename(uutpath)
    tb_file = get_tb_file(uutpath)
    uut_file = os.path.join(uutpath, "src", uutname+".vhd")

    lines_without_comments = ""
    try:
        with open(uut_file, "r") as f:
            for line in f.readlines():
                lines_without_comments += (line.strip("\n")).split("--")[0]
    except:
        parser.print_help()
        exit()

    filestring = re.sub(r'\s+', ' ', lines_without_comments)
    filestring = filestring.replace(";", "; ")
    filestring = filestring.replace(";  ", "; ")

    # print(filestring)
    entity_glob = PARSER.ParserType("entity", filestring, uutname).string
    # # print(entity.__dict__)
    # # print(entity_glob)
    ports_parser = PARSER.ParserType("port", entity_glob)
    generics_parser = PARSER.ParserType("generic", entity_glob)
    entity_inst = PARSER.Entity(ports_parser, generics_parser)
    # print(entity_inst.buses)
    # arch_glob = PARSER.ParserType(PARSER.VHDL_ARCH["type"][0],
    #                               filestring, uutname)
    # print(arch_glob.string["arch_decl"])
    # print(arch_glob.string["arch_def"])


