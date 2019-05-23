-------------------------------------------------------------------------------
-- COPYRIGHT (c) 2007-2014 Schweitzer Engineering Laboratories, Inc.
-- SEL Confidential
--
-- Description:  Print functions to display test results at simulation console
--               or to a text file.
--
-- Notes:  Simplifies status reporting in testbenches
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;

library std;
use std.textio.all;

package print_fnc_pkg is
  procedure print(arg : in string);
  procedure print(file out_file : text; arg : in string);
  procedure print(variable arg : in line);
  procedure print(arg : in string; t: in time);
  procedure print(a : in std_logic_vector);
  procedure print(a : in std_logic_vector;
                  b : in std_logic_vector);
  procedure print(a : in std_logic_vector;
                  b : in std_logic_vector;
                  c : in std_logic_vector);
  procedure print(a : in std_logic_vector;
                  b : in std_logic_vector;
                  c : in std_logic_vector;
                  d : in std_logic_vector);
  procedure print(a : in string;
                  b : in std_logic_vector);
  procedure print(a : in string;
                  b : in std_logic_vector;
                  c : in string;
                  d : in std_logic_vector);
  procedure print(a : in string;
                  b : in std_logic_vector;
                  c : in string;
                  d : in std_logic_vector;
                  e : in string;
                  f : in std_logic_vector);
  procedure print(a : in string;
                  b : in std_logic_vector;
                  c : in string;
                  d : in std_logic_vector;
                  e : in string;
                  f : in std_logic_vector;
                  g : in string;
                  h : in std_logic_vector);
  procedure print(a : in string;
                  b : in integer;
                  c : in string;
                  d : in integer);
  procedure print(identifier  : in string;
                  line_num    : in integer;
                  comment     : inout line);
  procedure print(identifier  : in string;
                  description : in string;
                  line_num    : in integer;
                  comment     : inout line);
  procedure print(identifier  : in string;
                  description : in string);
  procedure report_err(identifier  : in string;
                       description : in string;
                       line_num    : in integer;
                       comment     : inout line);
  procedure report_err(good        : in boolean;
                       identifier  : in string;
                       description : in string;
                       line_num    : in integer;
                       comment     : inout line);
  procedure print_err (identifier  : in string;
                       description : in string;
                       line_num    : in integer;
                       comment     : inout line);
  procedure print_err (good        : in boolean;
                       identifier  : in string;
                       description : in string;
                       line_num    : in integer);
  procedure print_err (good        : in boolean;
                       identifier  : in string;
                       description : in string;
                       line_num    : in integer;
                       comment     : inout line);
  procedure print_err (good        : in boolean;
                       identifier  : in string;
                       description : in string;
                       line_num    : in integer;
                       comment     : inout line;
                       pass         : inout boolean);
  procedure print_err (identifier  : in string;
                       description : in string;
                       line_num    : in integer;
                       comment     : inout line;
                       pass        : inout boolean);
  procedure print_err (good        : in boolean;
                       identifier  : in string;
                       description : in string);
  procedure print_err (good        : in boolean;
                       identifier  : in string;
                       description : in string;
                       pass        : inout boolean);
  procedure print_err (identifier  : in string;
                       description : in string);
  procedure print_err (identifier  : in string;
                       description : in string;
                       pass        : inout boolean);
  procedure print_warn(identifier  : in string;
                       description : in string);
  procedure print_warn(good        : in boolean;
                       identifier  : in string;
                       description : in string);
  procedure print_warn(identifier  : in string;
                       description : in string;
                       line_num    : in integer;
                       comment     : inout line);
  procedure print_warn(good        : in boolean;
                       identifier  : in string;
                       description : in string;
                       line_num    : in integer;
                       comment     : inout line);
  procedure print_result(identifier : in string;
                         pass       : in boolean);
  function  vec_to_str (x : in std_logic_vector) return string;
  function  bit_to_str (x : in std_logic) return string;
  function  vec_to_hex (x : in std_logic_vector) return string;
  function  cmp_vec    (x : in std_logic_vector;
                        y : in std_logic_vector) return boolean;
  function  cmp_vec    (x : in std_logic;
                        y : in std_logic) return boolean;
  function  cmp_vec    (x : in std_logic_vector;
                        y : in std_logic) return boolean;
  function  cmp_vec    (x : in std_logic;
                        y : in std_logic_vector) return boolean;
  function  cmp_vec    (x : in std_logic_vector;
                        y : in std_logic_vector;
                        be : in std_logic_vector) return boolean;
end print_fnc_pkg;

package body print_fnc_pkg is

  type char_indexed_by_MVL9 is array (STD_ULOGIC) of character;
  constant MVL9_to_char: char_indexed_by_MVL9 := "UX01ZWLH-";

  -- Convert std_logic_vector to a string, each bit is a character
  function vec_to_str (x : in std_logic_vector) return string is
    variable buf : string(1 to x'LENGTH);
    variable tmp : std_logic_vector(x'LENGTH -1 downto 0);
  begin
    tmp := x;
    for i in 1 to x'LENGTH loop
      buf(i) := MVL9_to_char(tmp(x'LENGTH-i));
    end loop;
    return buf;
  end function vec_to_str;

  -- Convert std_logic to a string
  function bit_to_str (x : in std_logic) return string is
    variable buf : string(1 to 1);
  begin
    buf(1) := MVL9_to_char(x);
    return buf;
  end function bit_to_str;

  -- Convert std_logic_vector to a hexadecimal string
  function vec_to_hex (x : in std_logic_vector) return string is
    variable size : integer range 1 to x'length+3;
    variable buf : string(1 to (x'length+3)/4);
    variable tmp : std_logic_vector(x'length+2 downto 0);
    variable quad : std_logic_vector(3 downto 0);
  begin
    --init tmp & size
    --pad upper bits with most significant bit only if the leftmost bit is not 1
    tmp := (others=>x(x'left)) when x(x'left) /= '1' else (others => '0');
    tmp(x'length-1 downto 0) := x; --assign current bits
    size := x'length;
    --round size up to nearest multiple of 4
    for i in 1 to 3 loop
      if ((size mod 4) /= 0) then
        size := size + 1;
      end if;
    end loop;
    --convert every 4 bits to one character
    for i in 0 to size/4-1 loop
      quad := tmp(size-(4*i)-1 downto size-(4*(i+1)));
      case quad is
        when x"0" => buf(i+1) := '0';
        when x"1" => buf(i+1) := '1';
        when x"2" => buf(i+1) := '2';
        when x"3" => buf(i+1) := '3';
        when x"4" => buf(i+1) := '4';
        when x"5" => buf(i+1) := '5';
        when x"6" => buf(i+1) := '6';
        when x"7" => buf(i+1) := '7';
        when x"8" => buf(i+1) := '8';
        when x"9" => buf(i+1) := '9';
        when x"A" => buf(i+1) := 'A';
        when x"B" => buf(i+1) := 'B';
        when x"C" => buf(i+1) := 'C';
        when x"D" => buf(i+1) := 'D';
        when x"E" => buf(i+1) := 'E';
        when x"F" => buf(i+1) := 'F';
        when "ZZZZ" => buf(i+1) := 'Z';
        when "HHHH" => buf(i+1) := 'H';
        when "LLLL" => buf(i+1) := 'L';
        when "WWWW" => buf(i+1) := 'W';
        when "UUUU" => buf(i+1) := 'U';
        when "----" => buf(i+1) := '-';
        when others => buf(i+1) := 'X'; --display X if any bits are not 0 or 1
      end case;
    end loop;
    return buf;
  end function vec_to_hex;

  -----------------------------------------------------------------------------
  --Compare two vectors with don't care bits
  function cmp_vec(x : in std_logic_vector;
                   y : in std_logic_vector) return boolean is
    variable equal : boolean := true;
    variable x_tmp : std_logic_vector(x'length - 1 downto 0);
    variable y_tmp : std_logic_vector(y'length - 1 downto 0);
  begin
    if x'length /= y'length then
      equal := false;
    else
      --Map the input signals to vectors of known range.
      --X and Y are required to be the same length, but they
      --don't have to be the same range (i.e. compare (9 downto 2) to (0 to 7)
      --This method guarantees we do not get an out of range error
      --NOTE:  The left most bit is always compared to the left most bit
      --       regardless of whether the vectors are to or downto
      x_tmp := x;
      y_tmp := y;
      for i in x'length - 1 downto 0 loop
        if x_tmp(i) /= '-' and y_tmp(i) /= '-' and
           x_tmp(i) /= y_tmp(i) then  -- '-' is a don't care
          equal := false;
        end if;
      end loop;
    end if;
    return equal;
  end cmp_vec;

  -----------------------------------------------------------------------------
  --Compare two std_logic with don't care bits
  function cmp_vec(x : in std_logic;
                   y : in std_logic) return boolean is
    variable x_tmp : std_logic_vector(0 downto 0);
    variable y_tmp : std_logic_vector(0 downto 0);
  begin
    x_tmp(0) := x;
    y_tmp(0) := y;
    return cmp_vec(x_tmp, y_tmp);
  end cmp_vec;

  -----------------------------------------------------------------------------
  --Compare a vector with a std_logic with don't care bits.
  --The vector must be 1 bit wide to be considered equal to the std_logic.
  function cmp_vec(x : in std_logic_vector;
                   y : in std_logic) return boolean is
    variable y_tmp : std_logic_vector(0 downto 0);
  begin
    y_tmp(0) := y;
    return cmp_vec(x, y_tmp);
  end cmp_vec;

  -----------------------------------------------------------------------------
  --Compare a std_logic with a vector with don't care bits
  --The vector must be 1 bit wide to be considered equal to the std_logic.
  function cmp_vec(x : in std_logic;
                   y : in std_logic_vector) return boolean is
    variable x_tmp : std_logic_vector(0 downto 0);
  begin
    x_tmp(0) := x;
    return cmp_vec(x_tmp, y);
  end cmp_vec;

  -----------------------------------------------------------------------------
  --Compare two vectors with byte enables and don't care bits
  function cmp_vec(x : in std_logic_vector;
                   y : in std_logic_vector;
                   be : in std_logic_vector) return boolean is
    variable equal : boolean := true;
    variable x_tmp : std_logic_vector(x'length - 1 downto 0);
    variable y_tmp : std_logic_vector(y'length - 1 downto 0);
  begin
     if x'length /= y'length then
      equal := false;
    else
      --Map the input signals to vectors of known range.
      --X and Y are required to be the same length, but they
      --don't have to be the same range (i.e. compare (9 downto 2) to (0 to 7)
      --This method guarantees we do not get an out of range error
      --NOTE:  The left most bit is always compared to the left most bit
      --       regardless of whether the vectors are to or downto
      x_tmp := x;
      y_tmp := y;
      for i in x'length - 1 downto 0 loop
        if x_tmp(i) /= '-' and y_tmp(i) /= '-' and
           x_tmp(i) /= y_tmp(i) and be(i/8) = '1' then  -- '-' is a don't care
          equal := false;
        end if;
      end loop;
    end if;
    return equal;
  end cmp_vec;

  -- Display string data to simulation console --------------------------------
  procedure print(arg : in string) is
    variable l: line;
    begin
      write(l, now, justified=>right,field =>10, unit=> ns );
      write(l, string'("   "));
      write(l,arg);
      writeline(output,l);
  end print;

  -- Store string data in text file --------------------------------------------
  procedure print(file out_file : text; arg : in string) is
    variable l : line;
  begin
      write(l, now, justified=>right,field =>10, unit=> ns );
      write(l, string'("   "));
      write(l,arg);
      writeline(out_file,l);
  end print;

  -- Display line data to simulation console --------------------------------
 procedure print(variable arg : in line) is
    variable l: line;
    begin
      if (arg /= NULL) then
        write(l, now, justified=>right,field =>10, unit=> ns );
        write(l, string'("   "));
        write(l, string'(arg.all));
        writeline(output,l);
      end if;
  end print;

  -- Display string data with time stamp to simulation console ----------------
  procedure print(arg : in string; t : in time) is
    variable l: line;
    begin
      write(l, now, justified=>right,field =>10, unit=> ns );
      write(l, string'("   "));
      write(l,arg);
      write(l, string'(" "));
      write(l,t);
      writeline(output,l);
  end print;

  -- Display one vector in hex to simluation console --------------------------
  procedure print(a : in std_logic_vector) is
    variable l: line;
    begin
      write(l, now, justified=>right,field =>10, unit=> ns );
      write(l, string'("   "));
      write(l, vec_to_hex(a));
      writeline(output,l);
  end print;

  -- Display two vectors in hex to simluation console -------------------------
  procedure print(a : in std_logic_vector;
                  b : in std_logic_vector) is
    variable l: line;
    begin
      write(l, now, justified=>right,field =>10, unit=> ns );
      write(l, string'("   "));
      write(l,vec_to_hex(a));
      write(l, string'("   "));
      write(l,vec_to_hex(b));
      writeline(output,l);
  end print;

  -- Display three vectors in hex to simluation console -----------------------
  procedure print( a : in std_logic_vector;
                   b : in std_logic_vector;
                   c : in std_logic_vector) is
    variable l: line;
    begin
      write(l, now, justified=>right,field =>10, unit=> ns );
      write(l, string'("   "));
      write(l, vec_to_hex(a));
      write(l, string'("   "));
      write(l, vec_to_hex(b));
      write(l, string'("   "));
      write(l, vec_to_hex(c));
      writeline(output,l);
  end print;

  -----------------------------------------------------------------------------
  procedure print( a : in std_logic_vector;
                   b : in std_logic_vector;
                   c : in std_logic_vector;
                   d : in std_logic_vector) is
    variable l: line;
    begin
      write(l, now, justified=>right,field =>10, unit=> ns );
      write(l, string'("   "));
      write(l, vec_to_hex(a));
      write(l, string'("   "));
      write(l, vec_to_hex(b));
      write(l, string'("   "));
      write(l, vec_to_hex(c));
      write(l, string'("   "));
      write(l, vec_to_hex(d));
      writeline(output,l);
  end print;

  -----------------------------------------------------------------------------
  procedure print(a : in string;
                  b : in std_logic_vector) is
    variable l: line;
  begin
    write(l, now, justified=>right,field =>10, unit=> ns );
    write(l, string'("   "));
    write(l,a);
    write(l, string'("   "));
    write(l, vec_to_hex(b));
    writeline(output, l);
  end print;

  -----------------------------------------------------------------------------
  procedure print(a : in string;
                  b : in std_logic_vector;
                  c : in string;
                  d : in std_logic_vector) is
    variable l: line;
  begin
    write(l, now, justified=>right,field =>10, unit=> ns );
    write(l, string'("   "));
    write(l,a);
    write(l, string'("   "));
    write(l, vec_to_hex(b));
    write(l, string'("   "));
    write(l,c);
    write(l, string'("   "));
    write(l, vec_to_hex(d));
    writeline(output, l);
  end print;

  -----------------------------------------------------------------------------
  procedure print(a : in string;
                  b : in std_logic_vector;
                  c : in string;
                  d : in std_logic_vector;
                  e : in string;
                  f : in std_logic_vector) is
    variable l: line;
  begin
    write(l, now, justified=>right,field =>10, unit=> ns );
    write(l, string'("   "));
    write(l,a);
    write(l, string'("   "));
    write(l, vec_to_hex(b));
    write(l, string'("   "));
    write(l,c);
    write(l, string'("   "));
    write(l, vec_to_hex(d));
    write(l, string'(" "));
    write(l,e);
    write(l, string'("   "));
    write(l, vec_to_hex(f));
    writeline(output, l);
  end print;

  -----------------------------------------------------------------------------
  procedure print(a : in string;
                  b : in std_logic_vector;
                  c : in string;
                  d : in std_logic_vector;
                  e : in string;
                  f : in std_logic_vector;
                  g : in string;
                  h : in std_logic_vector) is
    variable l: line;
  begin
    write(l, now, justified=>right,field =>10, unit=> ns );
    write(l, string'("   "));
    write(l,a);
    write(l, string'("   "));
    write(l, vec_to_hex(b));
    write(l, string'("   "));
    write(l,c);
    write(l, string'("   "));
    write(l, vec_to_hex(d));
    write(l, string'(" "));
    write(l,e);
    write(l, string'("   "));
    write(l, vec_to_hex(f));
    write(l, string'("   "));
    write(l,g);
    write(l, string'("   "));
    write(l, vec_to_hex(h));
    writeline(output, l);
  end print;

  -----------------------------------------------------------------------------
  procedure print (a : in string;
                   b : in integer;
                   c : in string;
                   d : in integer) is
    variable l : line;
  begin
    write(l, now, justified=>right,field =>10, unit=> ns );
    write(l, string'("   "));
    write(l,a);
    write(l, string'("   "));
    write(l, natural'image(b));
    write(l, string'("   "));
    write(l,c);
    write(l, string'("   "));
    write(l, natural'image(d));
    writeline(output, l);
  end print;

  -----------------------------------------------------------------------------
  --Print Verbose
  procedure print (identifier  : in string;
                   description : in string;
                   line_num    : in integer;
                   comment     : inout line) is
  begin
    if comment /= null then
      print(identifier & ": " & description & " (Line " & natural'image(line_num) & ") " & comment.all);
    else
      print(identifier & ": " & description & " (Line " & natural'image(line_num) & ") ");
    end if;
  end print;

  -----------------------------------------------------------------------------
  --Print Verbose
  procedure print (identifier  : in string;
                   description : in string) is
  begin
    print(identifier & ": " & description);
  end print;

  -----------------------------------------------------------------------------
  --Print Comment
  procedure print (identifier  : in string;
                   line_num    : in integer;
                   comment     : inout line) is
  begin
    if comment /= null then
      print(identifier & ": (Line " & natural'image(line_num) & ") " & comment.all);
    else
      print(identifier & ": (Line " & natural'image(line_num) & ") ");
    end if;
  end print;

  -----------------------------------------------------------------------------
  procedure report_err (identifier  : in string;
                        description : in string;
                        line_num    : in integer;
                        comment     : inout line) is
  begin
    if comment /= null then
      report identifier & ": " & description & " (Line " & natural'image(line_num) & ") " & comment.all severity error;
    else
      report identifier & ": " & description & " (Line " & natural'image(line_num) & ") " severity error;
    end if;
  end report_err;

  -----------------------------------------------------------------------------
  procedure report_err (good        : in boolean;
                        identifier  : in string;
                        description : in string;
                        line_num    : in integer;
                        comment     : inout line) is
  begin
    if good = false then
      report_err(identifier, description, line_num, comment);
    end if;
  end report_err;

  -----------------------------------------------------------------------------
  procedure print_err (identifier  : in string;
                        description : in string;
                        line_num    : in integer;
                        comment     : inout line) is
  begin
    if comment /= null then
      print("ERROR : " & identifier & ": " & description & " (Line " & natural'image(line_num) & ") " & comment.all);
    else
      print("ERROR : " & identifier & ": " & description & " (Line " & natural'image(line_num) & ") ");
    end if;
  end print_err;
  -----------------------------------------------------------------------------
  procedure print_err (good        : in boolean;
                       identifier  : in string;
                       description : in string;
                       line_num    : in integer) is
    variable comment : line := null;
  begin
    if good = false then
      print_err(identifier, description, line_num, comment);
    end if;
  end print_err;
  -----------------------------------------------------------------------------
  procedure print_err (good        : in boolean;
                       identifier  : in string;
                       description : in string;
                       line_num    : in integer;
                       comment     : inout line) is
  begin
    if good = false then
      print_err(identifier, description, line_num, comment);
    end if;
  end print_err;
  -----------------------------------------------------------------------------
  procedure print_err (good        : in boolean;
                       identifier  : in string;
                       description : in string;
                       line_num    : in integer;
                       comment     : inout line;
                       pass        : inout boolean) is
  begin
    if good = false then
      print_err(identifier, description, line_num, comment);
    end if;
    pass := pass and good;
  end print_err;
  -----------------------------------------------------------------------------
  procedure print_err (identifier  : in string;
                       description : in string;
                       line_num    : in integer;
                       comment     : inout line;
                       pass        : inout boolean) is
  begin
    print_err(identifier, description, line_num, comment);
    pass := false;
  end print_err;
  ------------------------------------------------------------------------------
  procedure print_err (good        : in boolean;
                       identifier  : in string;
                       description : in string) is
  begin
    if good = false then
      print_err(identifier, description);
    end if;
  end print_err;
  ------------------------------------------------------------------------------
  procedure print_err (good        : in boolean;
                       identifier  : in string;
                       description : in string;
                       pass        : inout boolean) is
  begin
    if good = false then
      print_err(identifier, description);
      pass := false;
    end if;
  end print_err;
  ------------------------------------------------------------------------------
  procedure print_err (identifier  : in string;
                       description : in string) is
  begin
    print("ERROR : " & identifier & ": " & description);
  end print_err;
  ------------------------------------------------------------------------------
  procedure print_err (identifier  : in string;
                       description : in string;
                       pass        : inout boolean) is
  begin
    print_err(identifier, description);
    pass := false;
  end print_err;
  ------------------------------------------------------------------------------
  procedure print_warn(identifier  : in string;
                       description : in string) is
  begin
    print("WARNING : " & identifier & ": " & description);
  end print_warn;
  ------------------------------------------------------------------------------
  procedure print_warn(good        : in boolean;
                       identifier  : in string;
                       description : in string) is
  begin
    if good = false then
      print("WARNING : " & identifier & ": " & description);
    end if;
  end print_warn;
  -----------------------------------------------------------------------------
  procedure print_warn (identifier  : in string;
                        description : in string;
                        line_num    : in integer;
                        comment     : inout line) is
  begin
    if comment /= null then
      print("WARNING : " & identifier & ": " & description & " (Line " & natural'image(line_num) & ") " & comment.all);
    else
      print("WARNING : " & identifier & ": " & description & " (Line " & natural'image(line_num) & ") ");
    end if;
  end print_warn;
  -----------------------------------------------------------------------------
  procedure print_warn (good        : in boolean;
                        identifier  : in string;
                        description : in string;
                        line_num    : in integer;
                        comment     : inout line) is
  begin
    if good = false then
      print_warn(identifier, description,line_num,comment);
    end if;
  end print_warn;
  ------------------------------------------------------------------------------
  procedure print_result(identifier : in string;
                         pass       : in boolean) is
  begin
    if pass then
      print(IDENTIFIER & ": Completed successfully!");
    else
      print_err(IDENTIFIER, "FAILURES OCCURRED!!! See log for details.");
    end if;
  end procedure print_result;
end;
