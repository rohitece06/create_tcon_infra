-------------------------------------------------------------------------------
-- COPYRIGHT (c) 2007-2018 Schweitzer Engineering Laboratories, Inc.
-- SEL Confidential
--
-- Description: Parse lines into tokens, one token at a time.
--
-- Notes:
--
-------------------------------------------------------------------------------
library ieee;
library std;
use ieee.std_logic_1164.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use work.print_fnc_pkg.all;

package text_processing_pkg is
  function strcmp(a, b : string) return boolean;
  function is_whitespace(c : character) return boolean;
  procedure skip_whitespace(l : inout line);
  procedure extract_string(l : inout line; str : inout line);
  procedure extract_string(l : inout line; str : inout line; size : out natural);
  procedure extract_string(l : inout line; str : inout string);
  procedure extract_string(l : inout line; str : inout string; size : out natural);
  procedure extract_comment(l : inout line; comment : inout line);
  procedure extract_comment(l : inout line; comment : inout line; size : out natural);
  procedure extract_comment(l : inout line; comment : inout string);
  procedure extract_comment(l : inout line; comment : inout string; size : out natural);
  procedure extract_num(l : inout line; vec : out unsigned; success : out boolean);
  procedure extract_num(l : inout line; vec : out signed; success : out boolean);
  procedure extract_num(l : inout line; vec : out std_logic_vector; success : out boolean);
  procedure extract_num(l : inout line; num : out integer; success : out boolean);
  procedure extract_bin(l : inout line; vec : out unsigned; success : out boolean);
  procedure extract_bin(l : inout line; vec : out std_logic_vector; success : out boolean);
  procedure extract_bin(l : inout line; num : out natural; success : out boolean);
  procedure extract_hex(l : inout line; vec : out unsigned; success : out boolean);
  procedure extract_hex(l : inout line; vec : out std_logic_vector; success : out boolean);
  procedure extract_hex(l : inout line; num : out natural; success : out boolean);
  procedure get_line(file cmdfile  : text;
                     line_in  : inout line;
                     line_num : inout integer;
                     success  : inout boolean);
  procedure get_line(file cmdfile  : text;
                     line_in    : inout line;
                     line_num   : inout integer;
                     IDENTIFIER : in string);
  procedure get_line(file cmdfile  : text;
                     line_in    : inout line;
                     line_num   : inout integer;
                     IDENTIFIER : in string;
                     success    : inout boolean);
  procedure open_text(file cmdfile    : text;
                      FILE_NAME  : in string;
                      IDENTIFIER : in string;
                      line_num   : inout integer;
               signal end_sim    : out boolean);
  procedure open_text(file cmdfile    : text;
                      FILE_NAME  : in string;
                      IDENTIFIER : in string;
                      line_num   : inout integer);
  procedure open_text(file cmdfile : text; FILE_NAME : in string; IDENTIFIER : in string);
  procedure check_eof(file cmdfile : text;
                      IDENTIFIER : in string;
                      line_num   : inout integer);
  procedure check_eof(file cmdfile : text;
                      IDENTIFIER : in string;
                      line_num   : inout integer;
                      pass       : inout boolean);

  procedure find_and_remove_string(L : inout line; str : in string; found : out boolean);
end text_processing_pkg;

package body text_processing_pkg is
  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- Compare two strings, only look at length of shortest string
  function strcmp(a, b : string) return boolean is
    variable i       : integer := 1;
    variable max_len : integer;
    variable ret     : boolean := true;
  begin
    if ( a'length > b'length ) then
      max_len := b'length;
    else
      max_len := a'length;
    end if;

    while (i <= max_len and a(i) /= nul and b(i) /= nul) loop
      if ( a(i) /= b(i) ) then
        ret := false;
        exit;
      end if;

      i := i + 1;
    end loop;

    return ret;
  end function strcmp;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- Check for and remove white space in lines
  function is_whitespace(c : character) return boolean is
  begin
    return (c = ' ' or c = LF or c = HT or c = CR or c = VT or c = NUL);
  end function is_whitespace;

  procedure skip_whitespace(l : inout line) is
    variable c : character;
  begin
    if l /= NULL then
      while (l'length > 0 and is_whitespace(l(l'left)) ) loop
        read(l, c);
      end loop;
    end if;
  end procedure skip_whitespace;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- Extract string separated by whitespace
  procedure extract_string(l : inout line; str : inout string; size : out natural) is
    variable c   : character;
    variable len : natural := 0;
  begin

    skip_whitespace(l);
    if l /= NULL then
      if l'length > 0 then
        --Handle quoted string
        if l(l'left) = '"' then
          read(l, c);
          while ( l'length > 0 and l(l'left) /= '"' and len < str'length ) loop
            if ( l(l'left) = NUL ) then
              report "Unterminated string constant." severity warning;
              exit;
            end if;
            read(l, c);
            len := len + 1;
            str(len) := c;
          end loop;
          read(l, c);
        --Handle normal string
        else
          while( l'length > 0 and len < str'length and not(is_whitespace(l(l'left))) ) loop
            read(l, c);
            len := len + 1;
            str(len) := c;
          end loop;
        end if;
      end if;
    end if;
    size := len;
  end procedure extract_string;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- Overload extract string for calls that do not contain size output
  procedure extract_string(l : inout line; str : inout string) is
    variable len : natural;
  begin
    extract_string(l,str,len);
  end procedure extract_string;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- Overload extract string to support lines
  procedure extract_string(l : inout line; str : inout line; size : out natural) is
    variable tmp : string(1 to l'length);
    variable len : natural := 0;
  begin
    if ( str /= NULL ) then
      Deallocate(str);  --clear the target line to avoid memory leak
    end if;

    extract_string(l, tmp, len);

    if len /= 0 then
      str := new string'(tmp(1 to len));
    end if;
    size := len;
  end procedure extract_string;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- Overload extract string to support lines
  procedure extract_string(l : inout line; str : inout line) is
    variable len : natural;
  begin
    extract_string(l, str, len);
  end procedure extract_string;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- Extract remaining text from line as string (does not stop at whitespace)
  procedure extract_comment(l : inout line; comment : inout string; size : out natural) is
    variable c   : character;
    variable len : natural := 0;
  begin

    skip_whitespace(l);
    if l /= NULL then
      if l'length > 0 then
        --Handle quoted string
        if l(l'left) = '"' then
          read(l, c);
          while ( l'length > 0 and l(l'left) /= '"' and len < comment'length ) loop
            if ( l(l'left) = NUL ) then
              report "Unterminated string constant." severity warning;
              exit;
            end if;
            read(l, c);
            len := len + 1;
            comment(len) := c;
          end loop;
          read(l, c);
        --Handle normal string
        else
          while( l'length > 0 and len < comment'length ) loop
            read(l, c);
            len := len + 1;
            comment(len) := c;
          end loop;
        end if;
      end if;
    end if;
    size := len;
  end procedure extract_comment;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- Overload extract comment with no size
  procedure extract_comment(l : inout line; comment : inout string) is
    variable len : natural := 0;
  begin
    extract_comment(l,comment,len);
  end procedure extract_comment;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- Overload extract comment to support lines rather than strings
  procedure extract_comment(l : inout line; comment : inout line; size : out natural) is
    variable tmp : string(1 to l'length);
    variable len : natural := 0;
  begin
    if ( comment /= NULL ) then
      Deallocate(comment); --clear the target line to avoid memory leak
    end if;

   extract_comment(l,tmp,len);

    if len /= 0 then
      comment := new string'(tmp(1 to len));
    end if;
    size := len;
  end procedure extract_comment;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- Overload extract comment with no size
  procedure extract_comment(l : inout line; comment : inout line) is
    variable len : natural;
  begin
   extract_comment(l,comment,len);
  end procedure extract_comment;
  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Extract unsigned number separated by whitespace
  procedure extract_num(l : inout line; vec : out unsigned; success : out boolean) is
    variable result : unsigned(vec'range) := (OTHERS => '0');
    variable tmp    : unsigned(vec'range);
    variable c      : character;
    variable good   : boolean := FALSE;
  begin
    skip_whitespace(l);
    if l /= NULL then
      -- Check that we are not at the end of the line
      if (l'length > 0) then
        good := TRUE; -- Assume that we are 'good' until we fail
      else
        good := FALSE; -- If the line is empty, then the extraction fails
      end if;
      -- Look for leading '0x' or '0b', otherwise, assume decimal
      if ( good = TRUE and l(l'left) = '0' ) then
        read(l, c);
        if ( l'length > 0 ) then
          if    ( l(l'left) = 'x' or l(l'left) = 'X' ) then
            read(l, c);
            extract_hex(l,vec,success);
            return;
          elsif ( l(l'left) = 'b' or l(l'left) = 'B' ) then
            read(l, c);
            extract_bin(l,vec,success);
            return;
          end if;
        end if;
      end if;

      --if we get this far it must be decimal
      while ( l'length > 0 and not(is_whitespace(l(l'left))) and good = TRUE) loop
        read(l, c);
        if    ( '0' <= c and c <= '9' ) then
          tmp := to_unsigned(character'pos(c) - character'pos('0'), tmp'length);
        else
          if c = '_' or c = ',' then
            next; -- Underscore or comma character can be used to separate digits to improve readability
          end if;
          --report warning if character was not a '-' or '~' (assuming -/~ is don't care)
          assert (c = '-' or c = '~') report "Invalid character for decimal string." severity warning;
          good := FALSE;
          tmp := to_unsigned(0, tmp'length);
        end if;
        -- result := result * 10 + tmp
        result  := (result sll 3) + result + result + tmp;
      end loop;
    end if;
    vec := result;
    success := good;
  end procedure extract_num;

  -- Extract signed number separated by whitespace
  procedure extract_num(l : inout line; vec : out signed; success : out boolean) is
    variable result : unsigned(vec'range) := (OTHERS => '0');
    variable tmp    : unsigned(vec'range) := (others => '0');
    variable c      : character;
    variable good   : boolean := FALSE;
    variable is_negative : boolean := FALSE;
  begin
    skip_whitespace(l);
    if l /= NULL then
      -- Check that we are not at the end of the line
      if (l'length > 0) then
        good := TRUE; -- Assume that we are 'good' until we fail
      else
        good := FALSE; -- If the line is empty, then the extraction fails
      end if;
      -- Look for leading '0x' or '0b', otherwise, assume decimal
      if ( good = TRUE and l(l'left) = '0' ) then
        read(l, c);
        if ( l'length > 0 ) then
          if    ( l(l'left) = 'x' or l(l'left) = 'X' ) then
            read(l, c);
            extract_hex(l,tmp,success);
            vec := signed(tmp);
            return;
          elsif ( l(l'left) = 'b' or l(l'left) = 'B' ) then
            read(l, c);
            extract_bin(l,tmp,success);
            vec := signed(tmp);
            return;
          end if;
        end if;
      end if;

      -- If we get this far it must be decimal
      while ( l'length > 0 and not(is_whitespace(l(l'left))) and good = TRUE) loop
        read(l, c);
        if ( '0' <= c and c <= '9' ) then
          tmp := to_unsigned(character'pos(c) - character'pos('0'), tmp'length);
        elsif (c = '-' and not(is_whitespace(l(l'left)))) then
          is_negative := TRUE;
        else
          if c = '_' or c = ',' then
            next; -- Underscore or comma character can be used to separate digits to improve readability
          end if;
          --report warning if character was not a '~' or '-' (assuming '~' as don't cares)
          assert (c = '~' or ((is_whitespace(l(l'left)))))
              report "Invalid character for decimal string." severity warning;        
          good := FALSE;
          tmp := to_unsigned(0, tmp'length);
        end if;
        -- result := result * 10 + tmp
        result  := (result sll 3) + result + result + tmp;
      end loop;
    end if;
    if (is_negative) then
      vec := -signed(result);
    else
      vec := signed(result);
    end if;
    success := good;
  end procedure extract_num;

  --overload extract_num
  procedure extract_num(l : inout line; vec : out std_logic_vector; success : out boolean) is
    variable result : unsigned(vec'range);
  begin
    extract_num(l, result, success);

    vec := std_logic_vector(result);
  end procedure extract_num;

  -- overload extract_num
  procedure extract_num(l : inout line; num : out integer; success : out boolean) is
    variable tmp : signed(31 downto 0);
  begin
    extract_num(l,  tmp,  success);

    num := to_integer(tmp);
  end procedure extract_num;

  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- For binary numbers without a 0b, we cannot autodetect base without
  -- losing data. Therefore, this function forces binary detection.
  procedure extract_bin(l : inout line; vec : out std_logic_vector; success : out boolean) is
    variable result : std_logic_vector(vec'length-1 downto 0) := (OTHERS => 'U');
    variable tmp    : std_logic;
    variable good   : boolean;
    variable fail   : boolean := true;
  begin
    skip_whitespace(l);
    if l /= NULL then
      -- Check that we are not at the end of the line
      if (l'length > 0) then
        fail := FALSE; -- Assume that we are 'good' until we fail
      else
        fail := TRUE; -- If the line is empty, then the extraction fails
      end if;
      
      while ( l'length > 0 and not(is_whitespace(l(l'left))) ) loop
        if l(l'left) = '_' or l(l'left) = ','then
          read(l, tmp, good);
          next;  --Underscore and comma can be used to separate digits to improve readability
        end if;
        read(l, tmp, good);
        assert good report "Invalid character for binary string." severity warning;
        fail := fail or not good;
        result := result(result'length-2 downto 0) & tmp;
      end loop;
    end if;
    vec := result;
    success := not fail;
  end procedure extract_bin;

  --overload extract_bin
  procedure extract_bin(l : inout line; vec : out unsigned; success : out boolean) is
    variable result : std_logic_vector(vec'range);
  begin
    extract_bin(l, result, success);

    vec := unsigned(result);
  end procedure extract_bin;

  --overload extract_bin
  procedure extract_bin(l : inout line; num : out natural; success : out boolean) is
    variable tmp : unsigned(31 downto 0);
  begin
    extract_bin(l, tmp, success);

    num := to_integer(tmp);
  end procedure extract_bin;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- For hexadecimal numbers without a 0x, we cannot autodetect base without
  -- losing data. Therefore, this function forces binary detection.
  procedure extract_hex(l : inout line; vec : out unsigned; success : out boolean) is
    variable c      : character;
    variable result : unsigned(vec'range) := (OTHERS => '0');
    variable tmp    : unsigned(vec'range);
  begin
    skip_whitespace(l);
    if l /= NULL then
      -- Check that we are not at the end of the line
      if (l'length > 0) then
        success := TRUE; -- Assume that we are 'good' until we fail
      else
        success := FALSE; -- If the line is empty, then the extraction fails
      end if;

      while ( l'length > 0 and not(is_whitespace(l(l'left))) ) loop
        read(l, c);
        if    ( '0' <= c and c <= '9' ) then
          tmp := to_unsigned(character'pos(c) - character'pos('0'), tmp'length);
        elsif ( 'A' <= c and c <= 'F' ) then
          tmp := to_unsigned(character'pos(c) - character'pos('A') + 10, tmp'length);
        elsif ( 'a' <= c and c <= 'f' ) then
          tmp := to_unsigned(character'pos(c) - character'pos('a') + 10, tmp'length);
        elsif c = '-' then
          tmp := (others=>'-'); --we only use a nibble at a time so clearing all is ok
        elsif c = 'x' or c = 'X' then
          tmp := (others=>'X'); --we only use a nibble at a time
        elsif c = 'z' or c = 'Z' then
          tmp := (others=>'Z'); --we only use a nibble at a time
        elsif c = 'h' or c = 'H' then
          tmp := (others=>'H'); --we only use a nibble at a time
        elsif c = 'l' or c = 'L' then
          tmp := (others=>'L'); --we only use a nibble at a time
        elsif c = 'w' or c = 'W' then
          tmp := (others=>'W'); --we only use a nibble at a time
        elsif c = 'u' or c = 'U' then
          tmp := (others=>'U'); --we only use a nibble at a time
        elsif c = '_' or c = ',' then
          next; -- underscore can be used to separate digits to improve readability
        else
          report "Invalid character for hexadecimal string." severity warning;
          success := FALSE;
        end if;
        result  := (result sll 4);
        --The previous code simply added tmp to result, but you cannot add with '-'
        --When using '-' characters a concatenation is required, however, to properly
        --concatenate we need to verify there are at least 4 bits or we get range errors
        if result'length > 4 then
          result(result'right+3 downto result'right) := tmp(tmp'right+3 downto tmp'right);
        else
          result := tmp;
        end if;
      end loop;
    end if;
    vec := result;
  end procedure extract_hex;

  --overload extract_hex
  procedure extract_hex(l : inout line; vec : out std_logic_vector; success : out boolean) is
    variable result : unsigned(vec'range);
  begin
    extract_hex(l, result, success);

    vec := std_logic_vector(result);
  end procedure extract_hex;

  --overload extract_hex
  procedure extract_hex(l : inout line; num : out natural; success : out boolean) is
    variable tmp : unsigned(31 downto 0);
  begin
    extract_hex(l, tmp, success);

    num := to_integer(tmp);
  end procedure extract_hex;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Grab the next line with non-whitespace characters from a file
  -- Return false if such a line cannot be found
  procedure get_line(file cmdfile     : text;
                     line_in : inout line;
                     line_num : inout integer;
                     success  : inout boolean) is
  begin
    success := false; --assume failure
    while not (endfile(cmdfile) or success) loop
      readline(cmdfile,line_in); -- Read a line from the file
      line_num := line_num + 1;  --keep track of which line we are on
      skip_whitespace(line_in);
      next when line_in'length = 0;  -- Skip empty lines
      next when line_in(line_in'left) = '#'; --Skip lines that start with # to allow commenting out lines
      success := true; -- if we get here we have data
    end loop;
  end procedure get_line;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Overload procedure to add error reporting
  procedure get_line(file cmdfile : text;
                     line_in    : inout line;
                     line_num   : inout integer;
                     IDENTIFIER : in string) is
    variable success : boolean;
  begin
    get_line(cmdfile,line_in,line_num,success);
    print_err(success,IDENTIFIER,"Attempted to read a line from an empty file!");
  end procedure get_line;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Overload procedure to add error reporting and status return
  procedure get_line(file cmdfile : text;
                     line_in    : inout line;
                     line_num   : inout integer;
                     IDENTIFIER : in string;
                     success    : inout boolean) is
  begin
    get_line(cmdfile,line_in,line_num,success);
    print_err(success,IDENTIFIER,"Attempted to read a line from an empty file!");
  end procedure get_line;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Open text file, check for EOF and pop a line to remove the header
  procedure open_text(file cmdfile : text;
                      FILE_NAME  : in string;
                      IDENTIFIER : in string;
                      line_num   : inout integer;
               signal end_sim    : out boolean) is
    variable line_in   : line;
  begin
    file_open(cmdfile,FILE_NAME,READ_MODE);
    if endfile(cmdfile) then
      print_err(IDENTIFIER, "Empty file encountered!!!");
      end_sim <= true;
      file_close(cmdfile);
    else
      end_sim <= false;
      readline(cmdfile,line_in); --removes header in file
      line_num := 1; --we poped the first line
    end if;
    deallocate(line_in);
  end procedure open_text;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Open text file, check for EOF and pop a line to remove the header
  -- Overload procedure to make end_sim an optional argument
  procedure open_text(file cmdfile : text;
                      FILE_NAME  : in string;
                      IDENTIFIER : in string;
                      line_num   : inout integer) is
    variable line_in   : line;
  begin
    file_open(cmdfile,FILE_NAME,READ_MODE);
    if endfile(cmdfile) then
      print_err(IDENTIFIER, "Empty file encountered!!!");
      file_close(cmdfile);
    else
      readline(cmdfile,line_in); --removes header in file
      line_num := 1; --we poped the first line
    end if;
    deallocate(line_in);
  end procedure open_text;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Open text file, check for EOF and pop a line to remove the header
  -- Overload procedure to make line_num an optional argument
  procedure open_text(file cmdfile : text;
                      FILE_NAME  : in string;
                      IDENTIFIER : in string) is
    variable line_num  : integer := 0;
  begin
    open_text(cmdfile, FILE_NAME, IDENTIFIER, line_num);
  end procedure open_text;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- This function will print an error message in the file is not empty
  -- The intended use is to call this function when end_sim asserts to verify
  -- all test vectors have been read from the input file. Add an exception if
  -- the end of VEC file is encountered
  procedure check_eof(file cmdfile : text;
                      IDENTIFIER : in string;
                      line_num   : inout integer) is
    variable line_in  : line;
    variable str      : string(1 to 2);
    variable success  : boolean;
  begin
    get_line(cmdfile,line_in,line_num,success);
    extract_string(line_in,str);
    if (success and strcmp(str, "%@ END_VECTORS")) then
      get_line(cmdfile,line_in,line_num,success);
    end if;
    print_err(not success,IDENTIFIER, "File was not empty at end of simulation!!!", line_num, line_in);
  end procedure check_eof;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- This function will print an error message in the file is not empty
  -- The intended use is to call this function when end_sim asserts to verify
  -- all test vectors have been read from the input file
  -- Overload procedure to allow pass variable
  procedure check_eof(file cmdfile : text;
                      IDENTIFIER : in string;
                      line_num   : inout integer;
                      pass       : inout boolean) is
    variable line_in  : line;
    variable success  : boolean;
  begin
    get_line(cmdfile,line_in,line_num,success);
    print_err(not success,IDENTIFIER, "File was not empty at end of simulation!!!", line_num, line_in, pass);
  end procedure check_eof;
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- This function observes the provided line and determines if the 
  -- provided string is in that line. The string must match the beginning of the line
  -- (leading whitespace ignored). If found, the string is removed from
  -- the line and returns a Boolean value of true. Otherwise the line remains 
  -- unchanged and returns a Boolean false.
  -- Note, the string will be unaltered during the search within the line
  -----------------------------------------------------------------------------  
  procedure find_and_remove_string(L : inout line; str : in string; found : out boolean) is
    variable tmp : string(1 to str'length);
  begin
    found := false;
    skip_whitespace(L);
    if ( L'length >= str'length and L(1 to str'length) = str) then
      -- Skip the leading string
      read(L, tmp);

      found := true;
    end if;
    skip_whitespace(L);
  end procedure find_and_remove_string;
end;
