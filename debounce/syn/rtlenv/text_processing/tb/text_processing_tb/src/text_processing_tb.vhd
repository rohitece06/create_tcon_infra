-------------------------------------------------------------------------------
-- COPYRIGHT (c) 2016 Schweitzer Engineering Laboratories, Inc.
-- SEL Confidential
--
-- Description: Test bench for the text_processing testbench component.
--
-- Notes: Uses print_fnc to display data to simulation console.
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

use work.print_fnc_pkg.all;
use work.text_processing_pkg.all;

entity text_processing_tb is
  generic
  (
    INPUT_FILE1 : string := "input_stim.txt";
    INPUT_FILE2 : string := "input_num.txt";
    INPUT_FILE3 : string := "input_fileio_check.txt";
    INPUT_FILE4 : string := "empty_file.txt";
    INPUT_FILE5 : string := "whitespace_chars.txt";
    INPUT_FILE6 : string := "find_str_stim.txt";
    INPUT_FILE7 : string := "dump_stim.txt"
  );
end entity;

architecture tb of text_processing_tb is
  signal pass_extract_comment : boolean := false;
  signal pass_file_io : boolean := false;
 begin
   strcmp_test : process
     variable str1 : string(1 to 10) := "SELPullman";
     variable str2 : string(1 to 10) := "SELBothell";
     variable str3 : string(1 to 12) := "SELPullmanWa";
     variable str4 : string(1 to 11) := "SELBot hell";
     variable str5 : string(1 to 4)  := "SEL" & nul;
     variable result_strcmp1 : boolean; --NR
     variable result_strcmp2 : boolean; --NR
   begin
     print(string'("---------------------------------------------------"));
     print(string'("-Testbench for 'strcmp' function - Test Case A    -"));
     print(string'("---------------------------------------------------"));

     print_err(not(strcmp(str1,str2)),"strcmp","Result does not match expected value!");
     print_err(strcmp(str1,str3),"strcmp","Result does not match expected value!");
     print_err(not(strcmp(str4,str2)),"strcmp","Result does not match expected value!");
     print_err((strcmp(str5,str2)),"strcmp","Result does not match expected value!");
     print_err((strcmp(str2,str5)),"strcmp","Result does not match expected value!");

     print(string'("---------------------------------------------------"));
     print(string'("-Testbench for 'strcmp' function complete.        -"));
     print(string'("---------------------------------------------------"));
     wait;
   end process strcmp_test;

   is_whitespace_test : process
   variable c : character := 'a';
   variable t : character;
   begin
     print(string'("-------------------------------------------------------"));
     print(string'("-Testbench for 'is_whitespace' function - Test Case B -"));
     print(string'("-------------------------------------------------------"));

     t := ' ';
     print_err(is_whitespace(t) = true,"is_whitespace"," ' ' is a whitespace char");

     t := LF;
     print_err((is_whitespace(t) = true),"is_whitespace","LF is a whitespace char");

     t := HT;
     print_err(is_whitespace(t) = true,"is_whitespace","HT is a whitespace char");

     t := CR;
     print_err(is_whitespace(t)= true,"is_whitespace","CR is a whitespace char");

     t := VT;
     print_err((is_whitespace(t) = true),"is_whitespace","VT is a whitespace char");

     t := NUL;
     print_err(is_whitespace(t) = true,"is_whitespace","NUL is a whitespace char");

     print_err(is_whitespace(c) = false,"is_whitespace","c is not a whitespace char");

     print(string'("---------------------------------------------------"));
     print(string'("-Testbench for 'is_whitespace' function complete. -"));
     print(string'("---------------------------------------------------"));
     wait;
   end process is_whitespace_test;

   skip_whitespace_test : process
   -- Read from input file
   file inp_line    : text;
   variable line_in : line;
   variable line_num : integer := 0;
   begin
     file_open(inp_line,INPUT_FILE1,READ_MODE);
     print(string'("-----------------------------------------------------------"));
     print(string'("-Testbench 1 for 'skip_whitespace' function - Test Case C -"));
     print(string'("-----------------------------------------------------------"));

     loop
       if endfile(inp_line) then
         file_close(inp_line);
         exit;
       end if;
       readline(inp_line,line_in);
       skip_whitespace(line_in);
       print("skip_whitespace", line_num, line_in);
       line_num := line_num + 1;
     end loop;

     print(string'("-------------------------------------------------------"));
     print(string'("-Testbench 1 for 'skip_whitespace' function complete. -"));
     print(string'("-------------------------------------------------------"));
     wait;
   end process skip_whitespace_test;

   skip_whitespace_test_2 : process
   file inpfile     : text;
   file emptyfile1   : text;
   variable line_in : line;
   variable null_line : line;
   variable line_num : natural := 0;
   --variable line_good : boolean := true;
   begin
     open_text(inpfile,INPUT_FILE5,"whitespace_chars_test");
     print(string'("-----------------------------------------------------------"));
     print(string'("-Testbench 2 for 'skip_whitespace' function - Test Case C -"));
     print(string'("-----------------------------------------------------------"));

     skip_whitespace(line_in);
     readline(inpfile,line_in);
     skip_whitespace(line_in);
     readline(inpfile,line_in);
     skip_whitespace(line_in);
     readline(inpfile,line_in);
     skip_whitespace(line_in);
     readline(inpfile,line_in);
     skip_whitespace(line_in);
     get_line(inpfile,null_line,line_num,"null");
     print("skip_whitespace", line_num, null_line);

     print(string'("-------------------------------------------------------"));
     print(string'("-Testbench 2 for 'skip_whitespace' function complete. -"));
     print(string'("-------------------------------------------------------"));
     wait;
   end process skip_whitespace_test_2 ;

   extract_string_test : process
   file inp_line    : text;
   variable line_in : line;
   file line_dum : text;
   variable line_num : natural := 0;
   variable str     : string(1 to 10);
   variable str1    : string(1 to 5);
   variable l       : line;
   variable size    : natural;
   variable result : string(1 to 10) := "SELBothell";
   variable my_line : line;
   begin
     -- Read from input file
     extract_string(my_line,str,size);  -- Reading an empty line
     extract_comment(my_line,str,size); -- Reading an empty line
     file_open(inp_line,INPUT_FILE1,READ_MODE);
     file_open(line_dum,INPUT_FILE7,READ_MODE);

     print(string'("--------------------------------------------------------"));
     print(string'("-Testbench for 'extract_string' function - Test Case D -"));
     print(string'("--------------------------------------------------------"));
     loop
       if endfile(inp_line) then
         file_close(inp_line);
         exit;
       end if;
     readline(inp_line,line_in);
     extract_string(line_in,str,size);
     print("extract_string: (Line " & natural'image(line_num) & ") " & str);
     line_num := line_num + 1;
     print_err(strcmp(str,result),"strcmp","Result does not match expected value!");
     readline(inp_line,line_in);
     extract_string(line_in,str);
     print("extract_string: (Line " & natural'image(line_num) & ") " & str);
     line_num := line_num + 1;
     print_err(strcmp(str,result),"strcmp","Result does not match expected value!");
     readline(inp_line,line_in);
     extract_string(line_in,str);
     print("extract_string: (Line " & natural'image(line_num) & ") " & str);
     line_num := line_num + 1;
     print_err(strcmp(str,result),"strcmp","Result does not match expected value!");
     readline(inp_line,line_in);
     extract_string(line_in,l,size);
     print("extract_string: (Line " & natural'image(line_num) & ") " & str);
     line_num := line_num + 1;
     print_err(strcmp(str,result),"strcmp","Result does not match expected value!");
     readline(inp_line,line_in);
     print(string'("Text IO internal error expected"));
     extract_string(line_in,l);
     readline(inp_line,line_in); -- Read a line with len > str'length
     extract_string(line_in,str1);
     print("extract_string: (Line " & natural'image(line_num) & ") " & str1);
     line_num := line_num + 1;
     print_err(strcmp(str1,result),"strcmp","Result does not match expected value!");

     check_eof(line_dum,"check_eof",line_num);

     readline(inp_line,line_in);
     extract_string(line_in,str1,size);
     print_err(size = 3, "strcmp", "Result does not match expected value!");
     print_err(strcmp(str1,"SEL"),"strcmp","Result does not match expected value!");

     check_eof(inp_line,"UUT",line_num);   -- Read a line with len <= 0
     extract_string(line_in,str,size);
     extract_string(line_in,l,size);
     print("extract_string: (Line " & natural'image(line_num) & ") " & str);
     line_num := line_num + 1;

     end loop;

     print(string'("----------------------------------------------------"));
     print(string'("-Testbench for 'extract_string' function complete. -"));
     print(string'("----------------------------------------------------"));
     wait;
   end process extract_string_test;

   extract_comment_test : process
   file inp_line    : text;
   variable line_in : line;
   variable line_num : natural := 0;
   variable comment : string(1 to 26);
   variable comment_sm : string(1 to 5);
   variable str1    : string(1 to 5);
   variable result1 : string(1 to 10) := "SELBothell";
   variable l       : line;
   variable size    : natural;
   variable pass    : boolean;
   begin
     -- Read from input file
     open_text(inp_line,INPUT_FILE1,"UUT",line_num,pass_extract_comment);
     readline(inp_line,line_in);
     print(string'("---------------------------------------------------------"));
     print(string'("-Testbench for 'extract_comment' function - Test Case E -"));
     print(string'("---------------------------------------------------------"));
     loop
       if endfile(inp_line) then
         file_close(inp_line);
         exit;
       end if;
     readline(inp_line,line_in);
     extract_comment(line_in,comment,size);
     print_err(strcmp(comment,result1),"extract_comment","Result does not match expected value!");
     readline(inp_line,line_in);
     extract_comment(line_in,comment);
     extract_comment(line_in,l);
     print_err(strcmp(comment,result1),"extract_comment","Result does not match expected value!");
     readline(inp_line,line_in);
     print(string'("Text IO internal error expected"));
     extract_comment(line_in,comment);
     extract_comment(line_in,l);
     print("extract_comment: (Line " & natural'image(line_num) & ") " & comment);
     line_num := line_num + 1;
     print_err(strcmp(comment,result1),"extract_comment","Result does not match expected value!");
     readline(inp_line,line_in); -- Read a line with len > str'length
     extract_comment(line_in,str1,size);
     extract_comment(line_in,l,size);
     print("extract_comment: (Line " & natural'image(line_num) & ") " & str1);
     line_num := line_num + 1;
     readline(inp_line,line_in); -- remove extra line
     extract_comment(line_in,comment_sm,size);

     check_eof(inp_line,"UUT",line_num,pass);  -- Read a line with len <= 0
     extract_comment(line_in,l,size);
     extract_comment(line_in,l,size); -- remove extra line
     extract_comment(line_in,str1,size);
     print_err(l = NULL, "extract_comment", "Line is not empty!");
     print(l);
     end loop;
     print(string'("-----------------------------------------------------"));
     print(string'("-Testbench for 'extract_comment' function complete. -"));
     print(string'("-----------------------------------------------------"));
     wait;
   end process extract_comment_test;

   extract_num_test : process
   file inp_num     : text;
   variable line_in : line;
   variable null_line : line;
   variable line_num : natural := 0;
   variable data_signed : signed(7 downto 0);
   variable data_s : signed(0 downto 0);
   variable data_unsigned : unsigned(31 downto 0);
   variable data_hex_unsigned : unsigned(2 downto 0);
   variable data_hex : std_logic_vector(15 downto 0);
   variable data_bin : std_logic_vector(7 downto 0);
   variable data_int : integer;
   variable data_nat : natural;
   variable comment : line;
   variable success : boolean;
   variable data_good : boolean;
   variable hex_good : boolean;
   variable bin_good : boolean;
   variable line_good : boolean;
   begin
     -- Read from input file
     file_open(inp_num,INPUT_FILE2,READ_MODE);

     print(string'("---------------------------------------------------"));
     print(string'("-Testbench for 'extract_num', 'extract_bin', and   "));
     print(string'("'extract_hex' functions - Test Cases F, G, & H.    "));
     print(string'("---------------------------------------------------"));

     -- Read input values
     get_line(inp_num,line_in,line_num,"read signed number");
     extract_num(line_in,data_signed,data_good);
     print_err(data_good,"extract_num","1.Result does not match expected value!");

     get_line(inp_num,line_in,line_num,"read unsigned number with a don't care",success);
     extract_num(line_in,data_unsigned,data_good);
     print_err(not(data_good),"extract_num","2.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_hex,data_good);
     print("extract_num: (Line " & natural'image(line_num) & ") ", data_hex);
     line_num := line_num + 1;
     print_err(data_good,"extract_num","3.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_hex,data_good);
     print("extract_num: (Line " & natural'image(line_num) & ") ", data_hex);
     line_num := line_num + 1;
     print_err(data_good,"extract_num","3.1Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_hex,data_good);
     print("extract_num: (Line " & natural'image(line_num) & ") ", data_hex);
     line_num := line_num + 1;
     print("extract_num: (Line " & natural'image(line_num) & ") ", data_hex);
     line_num := line_num + 1;
     print_err(data_good,"extract_num","3.2Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_hex,data_good);
     print("extract_num: (Line " & natural'image(line_num) & ") ", data_hex);
     line_num := line_num + 1;
     print_err(data_good,"extract_num","3.3Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_bin,data_good);
     print("extract_num: (Line " & natural'image(line_num) & ") ", data_bin);
     line_num := line_num + 1;
     print_err(data_good,"extract_num","4.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_signed,data_good);
     print_err(data_good,"extract_num","5.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_hex(line_in,data_hex,hex_good);
     print("extract_num: (Line " & natural'image(line_num) & ") ", data_hex);
     line_num := line_num + 1;
     print_err(data_good,"extract_hex","6.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_bin(line_in,data_bin,bin_good);
     print("extract_num: (Line " & natural'image(line_num) & ") ", data_bin);
     line_num := line_num + 1;
     print_err(data_good,"extract_bin","7.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_signed,bin_good);
     print_err(bin_good,"extract_bin","8.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_signed,data_good);
     print_err(data_good,"extract_num","9.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_signed,data_good);
     print_err(data_good,"extract_num","10.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_signed,data_good);
     print_err(not(data_good),"extract_num","11.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_signed,data_good);
     print_err(not(data_good),"extract_num","12.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_unsigned,data_good);
     print_err(not(data_good),"extract_num","13.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_unsigned,data_good);
     print_err(not(data_good),"extract_num","14.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_signed,data_good);
     print_err(not(data_good),"extract_num","15.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_bin(line_in,data_bin,bin_good);
     print_err(not(data_good),"extract_bin","16.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_bin(line_in,data_hex,bin_good);
     print_err(not(data_good),"extract_bin","17.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_int,data_good);
     print_err(data_good,"extract_num","18.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_unsigned,data_good);
     print_err(data_good,"extract_num","19.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_unsigned,data_good);
     print_err(data_good,"extract_num","20.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_bin(line_in,data_nat,bin_good);
     print_err(bin_good,"extract_bin","21.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_hex(line_in,data_nat,hex_good);
     print_err(hex_good,"extract_hex","22.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_hex(line_in,data_unsigned,hex_good);
     print_err(not(hex_good),"extract_hex","23.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_hex(line_in,data_unsigned,hex_good);
     print_err(not(hex_good),"extract_hex","24.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_hex(line_in,data_hex_unsigned,hex_good);
     print_err((hex_good),"extract_hex","25.Result does not match expected value!");
     readline(inp_num,line_in);
     extract_num(line_in,data_unsigned,hex_good);
     print_err((hex_good),"extract_num","26.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_unsigned,bin_good);
     print_err((bin_good),"extract_num","27.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_unsigned,data_good);
     print_err(not(data_good),"extract_num","28.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_signed,bin_good);
     print_err(not(bin_good),"extract_num","29.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_signed,bin_good);
     print_err(not(bin_good),"extract_num","30.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_hex(line_in,data_unsigned,hex_good);
     print_err((hex_good),"extract_hex","31.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_signed,data_good);
     print_err((data_good),"extract_num","32.Result does not match expected value!");

     readline(inp_num,line_in); --'a' <= c = true and c <= 'f' = false
     extract_hex(line_in,data_hex_unsigned,hex_good);
     print_err(not(hex_good),"extract_hex","33.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_signed,data_good);
     print_err(not(data_good),"extract_num","33.1.Result does not match expected value!");
     
     readline(inp_num,line_in);
     extract_num(line_in,data_unsigned,data_good);
     print_err(not(data_good),"extract_num","33.2.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_unsigned,data_good);
     print_err((data_good),"extract_num","34.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(null_line,data_unsigned,data_good);
     print_err(not(data_good),"extract_num","35.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_bin(line_in,data_bin,data_good);
     print_err(not(data_good),"extract_num","35.1.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_signed,data_good);
     print_err((data_good),"extract_num","35.2.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_num(line_in,data_unsigned,data_good);
     print_err((data_good),"extract_num","35.3.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_hex(line_in,data_unsigned,data_good);
     print_err((data_good),"extract_num","35.4.Result does not match expected value!");

     readline(inp_num,line_in);
     extract_hex(line_in,data_unsigned,data_good);
     print_err(not(data_good),"extract_num","35.5.Result does not match expected value!");

     get_line(inp_num,line_in,line_num,line_good);
     extract_num(line_in,data_unsigned,data_good);
     print_err(not(data_good),"extract_num","36.Result does not match expected value!");

     get_line(inp_num,line_in,line_num,line_good);
     extract_num(null_line,data_signed,data_good);
     print_err(not(data_good),"extract_num","37.Result does not match expected value!");

     get_line(inp_num,line_in,line_num,line_good);
     extract_num(null_line,data_unsigned,data_good);
     print_err(not(data_good),"extract_num","38.Result does not match expected value!");

     get_line(inp_num,line_in,line_num,line_good);
     extract_bin(null_line,data_bin,data_good);
     print_err(not(data_good),"extract_num","39.Result does not match expected value!");

     get_line(inp_num,line_in,line_num,line_good);
     extract_hex(null_line,data_unsigned,data_good);
     print_err(not(data_good),"extract_num","40.Result does not match expected value!");


     wait;
   end process extract_num_test;

   file_io_check_process: process
   -- Read from input file
   file inpfile     : text;
   file emptyfile1   : text;
   file emptyfile2   : text;
   variable str     : string(1 to 10);
   variable line_in : line;
   variable null_line: line;
   variable line_num : natural := 0;
   variable line_good : boolean;
   variable data_unsigned : unsigned(65536 downto 0);
   variable size : natural;
   begin
     print(string'("-------------------------------------------------------"));
     print(string'("-Testbench for 'file io check' function - Test Case I -"));
     print(string'("-------------------------------------------------------"));
     open_text(inpfile,INPUT_FILE3,"file_io_check");

     get_line(inpfile,line_in,line_num,line_good);--removes header in file
     print("file_io_check", line_num, line_in);
     print_err(line_good,"file_io_check","Result does not match expected value!");
     get_line(inpfile,line_in,line_num,line_good);
     print("file_io_check", line_num, line_in);
     print_err(line_good,"file_io_check","Result does not match expected value :#!");
     get_line(inpfile,line_in,line_num,line_good);
     print("file_io_check", line_num, line_in);
     line_num := line_num + 1;
     print_err(line_good,"file_io_check","Result does not match expected value : empty line!");

     readline(inpfile,line_in);
     extract_comment(line_in,str,size);
     readline(inpfile,line_in);
     extract_string(line_in,str,size);
     print("file_io_check: (Line " & natural'image(line_num) & ") " & str);
     get_line(inpfile,null_line,line_num,line_good);
     print("file_io_check", line_num, null_line);
     check_eof(inpfile,"file_io_check",line_num);

     print(string'("Empty file encountered error expected"));
     open_text(emptyfile1,INPUT_FILE4,"empty_file1",line_num,pass_file_io);
     open_text(emptyfile2,INPUT_FILE4,"empty_file2",line_num);

     wait;
   end process file_io_check_process;

   verify_find_and_remove_string_proc : process
     -- Read from input file
     file inpfile     : text;
     variable str     : string(1 to 10);
     variable line_in : line;
     variable null_line: line;
     variable line_num : natural := 0;
     variable line_good : boolean;
     variable data_unsigned : unsigned(65536 downto 0);
     variable size : natural;
     variable found_string : boolean;
   begin

     print(string'("-------------------------------------------------------"));
     print(string'("-Testbench for 'find_and_remove_string' function - Test Case J- "));
     print(string'("-------------------------------------------------------"));
     file_open(inpfile,INPUT_FILE6,READ_MODE);

     -- Read input values
     get_line(inpfile,line_in,line_num,"read string");
     find_and_remove_string(line_in, "bar", found_string);
     print_err(found_string = true, "Normal Operation Check", "Result does not match expected value: string matches");

     find_and_remove_string(line_in, "bar", found_string);
     print_err(found_string = false, "Normal Operation Check", "Result does not match expected value: string was removed from line");

     readline(inpfile,line_in);
     find_and_remove_string(line_in, "foobar", found_string);
     print_err(found_string = false, "Normal Operation Check", "Result does not match expected value: whole string has to match");

     readline(inpfile,line_in);
     find_and_remove_string(line_in, "23", found_string);
     print_err(found_string = true, "Normal Operation Check", "Result does not match expected value: numeric strings match");

     readline(inpfile,line_in);
     find_and_remove_string(line_in, "233839238", found_string);
     print_err(found_string = false, "Normal Operation Check", "Result does not match expected value: string to compare is larger than line");

     find_and_remove_string(line_in, "23", found_string);
     print_err(found_string = true, "Normal Operation Check", "Result does not match expected value: removed whitespace");

     readline(inpfile,line_in);
     find_and_remove_string(line_in, "k30g0395", found_string);
     print_err(found_string = true, "Normal Operation Check", "Result does not match expected value: whitespace in middle of string");

     readline(inpfile,line_in);
     find_and_remove_string(line_in, "#@$114@#4", found_string);
     print_err(found_string = true, "Normal Operation Check", "Result does not match expected value: special characters");
     print_err(strcmp(line_in.all, ""), "Normal Operation Check", "Result does not match expected value: string removed");

     readline(inpfile,line_in);
     find_and_remove_string(line_in, """24 24""", found_string);
     print_err(found_string = true, "Normal Operation Check", "Result does not match expected value: special characters");
     print_err(line_in'length = 0, "Normal Operation Check", "Result does not match expected value: the space has been removed");

     readline(inpfile,line_in);
     find_and_remove_string(line_in,"The foo bar went home someday", found_string);
     print_err(found_string = true, "Normal Operation Check", "Result does not match expected value: whitespace");
     print_err(strcmp(line_in.all, "today"), "Normal Operation Check", "Result does not match expected value: string removed");
    
     find_and_remove_string(line_in,"today!", found_string);
     print_err(found_string = false, "Normal Operation Check", "Result does not match expected value: almost matched string failed");
     print_err(strcmp(line_in.all, "today"), "Normal Operation Check", "Result does not match expected value: string removed");

     find_and_remove_string(line_in,"today",found_string);
     print_err(found_string = true, "Normal Operation Check", "Result does not match expected value: remove the remaining");
     print_err(strcmp(line_in.all, ""), "Normal Operation Check", "Result does not match expected value: string removed");

     readline(inpfile,line_in);
     find_and_remove_string(line_in,"""the  foo  ", found_string);
     print_err(found_string = true, "Normal Operation Check", "Result does not match expected value: the extra whitespace is covered");

     find_and_remove_string(line_in,"hello  """, found_string);
     print_err(found_string = true, "Normal Operation Check", "Result does not match expected value: the extra whitespace is covered");

     -- Extra whitespace removed
     print_err(line_in'length = 0, "Normal Operation Check", "Result does not match expected value: whitespace removed");

     readline(inpfile,line_in);
     find_and_remove_string(line_in,"two", found_string);
     print_err(found_string = false, "Normal Operation Check", "Result does not match expected value: same size no match");

     wait;
   end process verify_find_and_remove_string_proc;

 end architecture;
