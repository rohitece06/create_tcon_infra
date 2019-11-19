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
            top_entity_path = os.path.abspath(os.getcwd(),
                                              os.path.join(args.component_path))
    else:
        top_entity_path = os.getcwd()

    top_entity = os.path.basename(top_entity_path)
