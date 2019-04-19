
import re
import os
import time
import argparse
import sys
import parser_classes as PARSER


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
            2)  Port mapping configuration json: provides mapping for
                components ports and instantiation of relevant tcon
                testbench component. Example:
                    {
                    "PORT_TYPE_1: ["port_name_1", "port_name_2",...],
                    "PORT_TYPE_2: ["port_name_1", "port_name_2",...],
                                :
                                :
                    }
                Valid PORT_TYPEs are (case-insensitive):
                    CLK, RST, IRB_MASTER, IRB_SLAVE, SAIF_MASTER,
                    SAIF_SLAVE, SD_MASTER, and SD_SLAVE
                    Notes:: Support AXI, ETH, SPI and others

                PORT_NAMEs should match UUT's port names.
                    Notes: Support for wildcards (* and ?) to come

            Note: If this file is not provided, this script will try
                  to infer PORT_TYPEs for component's ports by port
                  names. For example, if port name is clk or starts
                  with clk_ or ends with _clk, it will be assigned a
                  CLK type. Same goes with RST type (i.e., rst/reset, starts
                  with rst_ or ends with _rst). Additionally, if the
                  port name started with irb_ and saif_ (_rts/_cts/_rtr/_ctr)
                  it will be assigned to appropriate SAIF and IRB port
                  PORT_TYPEs, respectively, based on those ports' VHDL
                  direction type (in or out). For example, irb_wr is an input
                  to the UUT, then the UUT is a IRB slave otherwise a IRB
                  master

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


