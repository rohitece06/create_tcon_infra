#!/usr/bin/python3
import os
import time
import argparse
import parser_classes as PC
import logging


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
    #   1) tb build.pl needs to exist
    #   2) syn/rtlenv and all dependencies folders needs to exist
    #   3)
    ###########################################################################
    args = parser.parse_args()
    setloglevel(args.loglevel)
    if args.component_path:
        if os.path.isdir(args.component_path):
            uutpath = os.path.abspath(args.component_path)
        else:
            uutpath = os.path.abspath(os.getcwd(), os.path.join(uutpath))
    else:
        uutpath = os.getcwd()
    uutname = os.path.basename(uutpath)
    tb_obj = PC.TB(uutpath, uutname)
    tb_obj.generate_tb_file()
