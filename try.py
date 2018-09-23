import re
import parser_classes as PARSER

if __name__ == "__main__":
    lines_without_comments =""
    with open("debounce.vhdl", "r") as f:
        for line in f.readlines():
            lines_without_comments += (line.strip("\n")).split("--")[0]

    filestring = re.sub(r'\s+', ' ', lines_without_comments)


    # print(filestring)
    uutname = "debounce"
    entity_glob = PARSER.ParserType("entity", filestring, uutname).string
    # print(entity.__dict__)   
    # print(entity_glob)
    ports_parser = PARSER.ParserType("port", entity_glob)
    generics_parser = PARSER.ParserType("generic", entity_glob)
    entity_inst = PARSER.Entity(ports_parser, generics_parser)
    with open("filestring.log", "w") as f:
        f.write(generics_parser.string)
    
