-------------------------------------------------------------------------------
-- COPYRIGHT (c) 2007-19 Schweitzer Engineering Laboratories, Inc.
-- SEL Confidential
-- Description: IRB bus master for testing IRB components
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;

entity tb_tcon_irb_master is
  generic
  (
    A_WIDTH     : integer range 1 to 31 := 31;
    TIMEOUT     : positive := 1;
    FLOP_DELAY  : time := 1 ps;
    RD_ERR_FATAL: boolean := false
  );
  port
  (
    tcon_req  : in     std_logic;
    tcon_ack  : out    std_logic := 'Z';
    tcon_err  : out    std_logic := 'Z';
    tcon_addr : in     std_logic_vector(31 downto 0);
    tcon_data : inout  std_logic_vector;
    tcon_rwn  : in     std_logic;

    irb_clk   : in     std_logic;
    reset     : in     std_logic := '0';
    irb_addr  : out    std_logic_vector;
    irb_di    : in     std_logic_vector;
    irb_do    : out    std_logic_vector;
    irb_rd    : out    std_logic := '0';
    irb_wr    : out    std_logic := '0';
    irb_ack   : in     std_logic;
    irb_busy  : in     std_logic
  );
end tb_tcon_irb_master;

library ieee;
use ieee.std_logic_1164.all;

package tb_tcon_irb_master_pkg is
  component tb_tcon_irb_master is
  generic
  (
    A_WIDTH     : integer range 1 to 31 := 31;
    TIMEOUT     : positive := 1;
    FLOP_DELAY  : time := 1 ps;
    RD_ERR_FATAL: boolean := false
  );
  port
  (
    tcon_req  : in     std_logic;
    tcon_ack  : out    std_logic;
    tcon_err  : out    std_logic;
    tcon_addr : in    std_logic_vector(31 downto 0);
    tcon_data : inout  std_logic_vector;
    tcon_rwn  : in     std_logic;

    irb_clk   : in     std_logic;
    irb_addr  : out    std_logic_vector;
    irb_di    : in     std_logic_vector;
    irb_do    : out    std_logic_vector;
    irb_rd    : out    std_logic;
    irb_wr    : out    std_logic;
    irb_ack   : in     std_logic;
    irb_busy  : in     std_logic
  );
  end component tb_tcon_irb_master;
end package tb_tcon_irb_master_pkg;

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;

architecture behav of tb_tcon_irb_master is
  constant ZEROS : std_logic_vector(irb_di'range) := (others => '0');

  signal di_d   : std_logic_vector(irb_di'range)   := (others => '0');
  signal ack_d  : std_logic := '0';
  signal busy_d : std_logic := '0';
  signal irb_rd_i : std_logic := '0';
  signal save_irb_di : std_logic_vector(irb_di'range) := (others => '0');
  type ack_check_sm is (idle_st, check_st);
  signal state_ms : ack_check_sm := idle_st;
begin

  -- The IRB interface requires irb_di to maintain its value after ack asserts
  -- and must not change until another read
  -- by default, if the above is violated, it is a warning
  ack_checker : process(irb_clk)
  begin
    if rising_edge(irb_clk) then
      if irb_rd_i = '1' or reset = '1' then
        state_ms <= idle_st;
      else
        case state_ms is
          when check_st =>

            if RD_ERR_FATAL = false then
              assert save_irb_di = irb_di report "irb_di changed after ack and before next read pulse, interface not compliant with IRB standard" severity warning;
            else
              assert save_irb_di = irb_di report "irb_di changed after ack and before next read pulse, interface not compliant with IRB standard" severity error;
            end if;

          when others => -- idle

            if irb_ack = '1' then
              -- Save the IRB di value and transition
              save_irb_di <= irb_di;
              state_ms <= check_st;
            end if;
        end case;
      end if;
    end if;
  end process ack_checker;

  irb_rd <= irb_rd_i;
  di_d   <= transport irb_di   after FLOP_DELAY;
  ack_d  <= transport irb_ack  after FLOP_DELAY;
  busy_d <= transport irb_busy after FLOP_DELAY;

  main : process
    procedure irb_read(variable addr : in std_logic_vector;
                       variable data : out std_logic_vector;
                       variable err  : out boolean) is
      variable ack_count : integer := 0;
      variable irb_addr_i : std_logic_vector(irb_addr'range) := (others => '0');
    begin
      -- Drive the IRB bus control signals:
      if irb_addr'length > addr'length then
        irb_addr_i(tcon_addr'range) := addr;
      else --irb_addr'length <= tcon_addr'length
        irb_addr_i                  := addr(irb_addr_i'range);
      end if;
      
      irb_addr   <= transport irb_addr_i after FLOP_DELAY;
      irb_rd_i   <= transport '1'  after FLOP_DELAY;

      -- Wait for the next edge before idling the bus
      wait until rising_edge(irb_clk);

      -- Idle the bus.  Note that we do not revert the address or data to
      -- ensure proper coverage.
      irb_rd_i   <= transport '0'             after FLOP_DELAY;

      -- By default, an error
      err := true;

      -- Wait for the next edge to read the data and the bus
      while ( ack_count < TIMEOUT  ) loop
        wait until rising_edge(irb_clk);
        if data'length > di_d'length then
          data              := (data'range=>'0'); -- assign unused bits
          data(di_d'range)  := di_d;              -- overwrites as needed
        else -- data <= di_d/irb_di width:
          data              := di_d(data'range);
        end if;
        err := (ack_d /= '1');
        ack_count := ack_count + 1;
        exit when ack_d = '1';
      end loop;

      assert (ack_d = '1' or di_d = ZEROS) report "IRB data input not zero on unacknowledged read" severity error;
    end irb_read;

    procedure irb_write(variable addr : in std_logic_vector;
                        variable data : in std_logic_vector;
                        variable err  : out boolean) is
      variable busy_count : integer := 0;
      variable irb_addr_i : std_logic_vector(irb_addr'range) := (others => '0');
      variable irb_do_i   : std_logic_vector(irb_do'range)   := (others => '0');
    begin
      -- Drive the IRB bus control signals
      if irb_addr'length > addr'length then
        irb_addr_i(tcon_addr'range) := addr;
      else --irb_addr'length <= tcon_addr'length
        irb_addr_i                  := addr(irb_addr_i'range);
      end if;
 
      if irb_do'length > data'length then
        irb_do_i(data'range) := data;
      else -- irb_do <= tcon data width:
        irb_do_i             := data(irb_do'range);
      end if;

      irb_addr <= transport irb_addr_i after FLOP_DELAY;
      irb_do   <= transport irb_do_i   after FLOP_DELAY;
      irb_wr   <= transport '1'        after FLOP_DELAY;

      wait until rising_edge(irb_clk);

      -- Idle the bus.
      irb_wr   <= transport '0'   after FLOP_DELAY;

      -- By default, no error
      err := false;

      -- Wait for the next edge to read the data and the bus
      while ( busy_count < TIMEOUT ) loop
        wait until rising_edge(irb_clk);
        err := (busy_d = '1');
        busy_count := busy_count + 1;
        exit when busy_d = '0';
      end loop;
    end irb_write;

    variable addr : std_logic_vector(tcon_addr'range);
    variable data : std_logic_vector(tcon_data'range);
    variable err  : boolean;
  begin
    tcon_data <= (tcon_data'range => 'Z'); -- initialization

    -- Synchronize ourselves to the clock
    wait until rising_edge(irb_clk);

    while true loop
      -- Reset the outputs
      irb_rd_i   <= transport '0' after FLOP_DELAY;
      irb_wr     <= transport '0' after FLOP_DELAY;

      -- Indicate we are not busy
      tcon_ack  <= 'Z';
      tcon_err  <= 'Z';
      tcon_data <= (tcon_data'range => 'Z');

      -- Wait for a request
      wait until tcon_req = '1';

      -- Deassert ACK/ERR while busy
      tcon_ack <= '0';
      tcon_err <= '0';

      -- Translate directy to the IRB bus
      if ( tcon_req = '1' ) then
        addr := tcon_addr;
        data := tcon_data;
        if ( tcon_rwn = '1' ) then
          irb_read(addr, data, err);
          tcon_data <= data;
        else
          irb_write(addr, data, err);
        end if;
      end if;

      -- Either ACK or ERR
      if ( err ) then
        tcon_err <= '1';
      else
        tcon_ack <= '1';
      end if;

      -- Wait for the REQ to go away
      wait until tcon_req = '0';
    end loop;
  end process main;
end architecture behav;
