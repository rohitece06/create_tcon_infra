#!/usr/bin/python3.7
import re
import os
import time
import argparse
import sys
import parser_classes as PC
from inspect import currentframe
import logging
from typing import NoReturn


def setloglevel(loglevel: str) -> NoReturn:
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


def get_tb_file(comppath: str) -> str:
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

    ###########################################################################
    #
    #           TODO:: perform sanity checks
    #
    ###########################################################################
    args = parser.parse_args()
    setloglevel(args.loglevel)
    uutpath = os.path.abspath(os.path.join(args.component_path)) \
        if args.component_path else os.getcwd()

    uutname = os.path.basename(uutpath)
    tb_obj = PC.TB(uutpath, uutname)
    # tb_obj.uut.print_generics()
    # tb_obj.uut.print_ports()
    # print("\n")
    # for bus, entry in tb_obj.uut.port_buses.items():
    #     print(bus, "\t", entry)
    # print("\n")
    # tb_obj.tcon_master.print_generics()
    # tb_obj.tcon_master.print_ports()

    # for dep in tb_obj.tb_dep:
    #     PC.log.setLevel(logging.INFO)
    #     print("\n\n")
    #     PC.log.info(f"{dep.name}\n\n")
    #     PC.log.setLevel(logging.ERROR)
    #     for generic in dep.generics:
    #         print(generic)
    #     for port in dep.ports:
    #         print(port)

    tb_obj.generate_mapping()
    print("".join(tb_obj.arch_decl))
    print("".join(tb_obj.arch_def))
