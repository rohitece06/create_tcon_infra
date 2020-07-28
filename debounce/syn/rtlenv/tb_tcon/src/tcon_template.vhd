--------------------------------------------------------------------------------
-- COPYRIGHT (c) 2018 Schweitzer Engineering Laboratories, Inc.
-- SEL Confidential
--
-- Description:  Scripted testbench (T) controller (CON)
--------------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;

entity tb_tcon is
  generic
  (
    INST_NAME    : string;
    COMMAND_LINE : string
  );
  port
  (
    -- Tcon master port
    tcon_req  : out   std_logic_vector;
    tcon_ack  : in    std_logic;
    tcon_err  : in    std_logic;
    tcon_addr : out   std_logic_vector;
    tcon_data : inout std_logic_vector;
    tcon_rwn  : out   std_logic;

    tcon_clk  : in std_logic;
    tcon_gpio : inout std_logic_vector
  );
end entity tb_tcon;

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

architecture behav of tb_tcon is
  attribute foreign of behav : architecture is "init <dll_name>";
begin
end architecture behav;