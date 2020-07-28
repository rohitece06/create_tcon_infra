--------------------------------------------------------------------------------
-- Copyright (c) 2019 Schweitzer Engineering Laboratories, Inc.
-- SEL Confidential
-- hmi_led testbench
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tb_tcon_irb_slave_pkg.all;

entity tb_tcon_irb_slave_tb is
  generic
  (
    TEST_FOLDER : string;
    DATA_WIDTH  : positive  := 32;
    ADDR_WIDTH  : positive  := 32;
    BASE_ADDR   : natural   := 0;
    HIGH_ADDR   : natural   := 16383
  );
end entity tb_tcon_irb_slave_tb;

architecture behav of tb_tcon_irb_slave_tb is
  constant REGION_PARAMS : region_param_array :=
  (
    0 => ( BASE_ADDRESS   => std_logic_vector(to_unsigned(BASE_ADDR, ADDR_WIDTH)),
           SIZE           => HIGH_ADDR - BASE_ADDR + 1,
           ACCESS_MODE    => read,
           WRITE_PRIORITY => tcon
         )
  );

  -- TCON REQ
  constant REQ_CLOCKER    : natural := 0;
  constant REQ_IRB_MASTER : natural := 1;
  constant REQ_IRB_SLAVE  : natural := 2;

  -- TCON GPIOs
  constant GPIO_RESET     : natural := 0;

  -- Tcon signals
  signal tcon_req         : std_logic_vector(31 downto 0);
  signal tcon_ack         : std_logic;
  signal tcon_err         : std_logic;
  signal tcon_addr        : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal tcon_data        : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal tcon_rwn         : std_logic;
  signal tcon_gpio        : std_logic_vector(15 downto 0);
  alias reset             is tcon_gpio(GPIO_RESET);

  -- CLK
  signal clks             : std_logic_vector (0 downto 0);
  alias clk               is clks(0);

  -- IRB interface
  signal irb_addr         : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal irb_rd           : std_logic;
  signal irb_wr           : std_logic;
  signal irb_di           : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal irb_do           : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal irb_ack          : std_logic;

begin  
  -----------------------------------------------------------------------------
  -- TCON
  -----------------------------------------------------------------------------
  tcon_inst : entity work.tb_tcon
  generic map
  (
    INST_NAME    => "tcon",
    COMMAND_LINE => "py -3 -u " & TEST_FOLDER & "/tcon.py"
  )
  port map
  (
    tcon_clk  => clk,
    tcon_req  => tcon_req,
    tcon_ack  => tcon_ack,
    tcon_err  => tcon_err,
    tcon_addr => tcon_addr,
    tcon_data => tcon_data,
    tcon_rwn  => tcon_rwn,
    tcon_gpio => tcon_gpio
  );

  -----------------------------------------------------------------------------
  -- CLOCKER
  -----------------------------------------------------------------------------
  clocker : entity work.tb_tcon_clocker
    generic map
    (
      NUM_CLOCKS => 1
    )
    port map
    (
      tcon_req  => tcon_req(REQ_CLOCKER),
      tcon_ack  => tcon_ack,
      tcon_err  => tcon_err,
      tcon_addr => tcon_addr,
      tcon_data => tcon_data,
      tcon_rwn  => tcon_rwn,
      
      clks    => clks
    );

  -----------------------------------------------------------------------------
  -- IRB Master
  -----------------------------------------------------------------------------
  irb_master : entity work.tb_tcon_irb_master
  generic map
  (
    A_WIDTH => 31
  )
  port map
  (
    tcon_req  => tcon_req(REQ_IRB_MASTER),
    tcon_ack  => tcon_ack,
    tcon_err  => tcon_err,
    tcon_addr => tcon_addr,
    tcon_data => tcon_data,
    tcon_rwn  => tcon_rwn,

    irb_clk  => clk,
    irb_addr => irb_addr,
    irb_di   => irb_do,
    irb_do   => irb_di,
    irb_rd   => irb_rd,
    irb_wr   => irb_wr,
    irb_ack  => irb_ack,
    irb_busy => '0'
  );

  ------------------------------------------------------------------------------
  -- UUT
  ------------------------------------------------------------------------------
  UUT: entity work.tb_tcon_irb_slave
  generic map
  (
    REGION_PARAMS => REGION_PARAMS
  )
  port map
  (
    tcon_req  => tcon_req(REQ_IRB_SLAVE),
    tcon_ack  => tcon_ack,
    tcon_err  => tcon_err,
    tcon_addr => tcon_addr,
    tcon_data => tcon_data,
    tcon_rwn  => tcon_rwn,
    tcon_be   => "1111", 

    irb_clk   => clk,
    irb_addr  => irb_addr,
    irb_di    => irb_di,
    irb_do    => irb_do,
    irb_rd    => irb_rd,
    irb_wr    => irb_wr,
    irb_ack   => irb_ack,
    irb_be    => "1111"
  );



end architecture behav;