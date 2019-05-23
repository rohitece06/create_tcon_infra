-------------------------------------------------------------------------------
-- COPYRIGHT (c) 2016 Schweitzer Engineering Labs, Pullman, Washington
-- SEL Confidential
--
-- Description: start/done slave test bench component
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.print_fnc_pkg.all;

entity tb_tcon_start_done_slave is
  generic
  (
    DATA_WIDTH      : positive;
    FLAG_WIDTH      : natural;
    LOG_FILE        : string;
    IDENTIFIER      : string := "tb_tcon_start_done_slave";
    FLOP_DELAY      : time := 1 ps
  );
  port
  (
    tcon_req  : in    std_logic := '0';
    tcon_ack  : out   std_logic := 'Z';
    tcon_err  : out   std_logic := 'Z';
    tcon_addr : in    std_logic_vector(31 downto 0);
    tcon_data : inout std_logic_vector;
    tcon_rwn  : in    std_logic := '0';

    clk       : in  std_logic;
    reset     : in  std_logic;
    start     : in  std_logic;
    delay     : in  natural;
    done      : out std_logic := '0';
    data      : in  std_logic_vector(DATA_WIDTH+FLAG_WIDTH-1 downto 0);
    unpause   : in  std_logic;
    is_paused : out boolean -- NR
  );
end entity tb_tcon_start_done_slave;


library ieee;
use ieee.std_logic_1164.all;

package tb_tcon_start_done_slave_pkg is

  component tb_tcon_start_done_slave is
    generic
    (
      DATA_WIDTH      : positive;
      FLAG_WIDTH      : natural;
      LOG_FILE        : string;
      IDENTIFIER      : string;
      FLOP_DELAY      : time := 1 ps
    );
    port
    (
      tcon_req  : in    std_logic := '0';
      tcon_ack  : out   std_logic := 'Z';
      tcon_err  : out   std_logic := 'Z';
      tcon_addr : in    std_logic_vector(31 downto 0);
      tcon_data : inout std_logic_vector;
      tcon_rwn  : in    std_logic := '0';

      clk       : in  std_logic;
      reset     : in  std_logic;
      start     : in  std_logic;
      delay     : in  natural;
      done      : out std_logic := '0';
      data      : in  std_logic_vector(DATA_WIDTH+FLAG_WIDTH-1 downto 0);
      unpause   : in  std_logic;
      is_paused : out boolean -- NR
    );
  end component tb_tcon_start_done_slave;

end package tb_tcon_start_done_slave_pkg;


library ieee;
use ieee.numeric_std.all;

library std;
use std.textio.all;

architecture rtl of tb_tcon_start_done_slave is

  -- TCON Interface Registers
  constant REG_START_COUNT : natural := 0;
  constant REG_DONE_COUNT  : natural := 1;
  constant REG_DELAY_COUNT : natural := 2;
  constant REG_STATUS      : natural := 3;

  -----------------------------------------------------------------------------
  -- Declarations
  -----------------------------------------------------------------------------
  type state_t is protected

    -- Getters
    impure function get_start_count return natural;
    impure function get_done_count  return natural;
    impure function get_delay_count return natural;

    -- Status
    impure function is_delayed return boolean;

    -- Setters
    procedure set_delay(constant delay : in integer);
    procedure increment_start_count;
    procedure reset_start_count;
    procedure increment_done_count;
    procedure reset_done_count;
    procedure decrement_delay_count;

  end protected state_t;

  -----------------------------------------------------------------------------
  -- Definitions
  -----------------------------------------------------------------------------
  type state_t is protected body

    variable start_count : natural := 0;
    variable done_count  : natural := 0;
    variable delay_count : integer := -1;

    impure function get_start_count return natural is begin
      return start_count;
    end function get_start_count;

    impure function get_done_count return natural is begin
      return done_count;
    end function get_done_count;

    impure function get_delay_count return natural is begin
      if delay_count > 0 then
        return delay_count;
      else
        return 0;
      end if;
    end function get_delay_count;

    procedure set_delay(constant delay : in integer) is begin
      delay_count := delay;
    end procedure set_delay;

    impure function is_delayed return boolean is begin
      return delay_count >= 0;
    end function is_delayed;

    procedure increment_start_count is begin
      start_count := start_count + 1;
    end procedure increment_start_count;

    procedure reset_start_count is begin
      start_count := 0;
    end procedure reset_start_count;

    procedure increment_done_count is begin
      done_count := done_count + 1;
    end procedure increment_done_count;

    procedure reset_done_count is begin
      done_count := 0;
    end procedure reset_done_count;

    procedure decrement_delay_count is begin
      delay_count := delay_count - 1;
    end procedure decrement_delay_count;

  end protected body state_t;

  function to_stdlogic(x : boolean) return std_logic is begin
    if x then return '1'; else return '0'; end if;
  end function to_stdlogic;

  shared variable state : state_t;
  signal data_at_start : std_logic_vector(data'range) := (others => '0');
  signal started : boolean := false; -- in a start-done cycle

-------------------------------------------------------------------------------
begin -------------------------------------------------------------------------
-------------------------------------------------------------------------------

  is_paused <= false;

  main_loop : process
    variable status    : file_open_status;
    file     logf      : text;
    variable outline   : line;
  begin

    -- Open the log file.  Halts and displays a failure message if needed.
    file_open(status, logf, LOG_FILE, write_mode);

    start_loop : loop
      -- Wait for the start pulse
      wait until rising_edge(clk) and start = '1' and reset /= '1';
      state.increment_start_count;

      -- Dump the data
      hwrite(outline, data(DATA_WIDTH-1 downto 0));
      -- Then the flags
      flags_loop: for i in 0 to FLAG_WIDTH-1 loop
        write(outline, ' ');
        write(outline, data(DATA_WIDTH+FLAG_WIDTH-1-i));
      end loop flags_loop;

      -- Dump the line to the file
      writeline(logf, outline);

      -- Delay the done pulse
      state.set_delay(delay);
      delay_loop: while state.get_delay_count > 0 loop
        wait on clk, reset;
        if reset = '1' then
          state.set_delay(-1);
          next start_loop;
        elsif rising_edge(clk) then
          state.decrement_delay_count;
        end if;
      end loop delay_loop;
      wait for FLOP_DELAY;
      done <= '1';
      wait for FLOP_DELAY;

      wait until rising_edge(clk);
      state.increment_done_count;
      wait for FLOP_DELAY;
      done <= '0';
      state.decrement_delay_count; -- Set to -1 to indicate no more delay
    end loop start_loop;

  end process main_loop;

  -- Monitor that data doesnt change between start and done if start was de-asserted
  -- between a start-done cycle
  mon_proc: process(clk)
  begin
    if rising_edge(clk) then
      if reset /= '1' then
        -- Register data with start to compare with data currently on data bus
        -- started flag indicates that a start came but the corresponding done has
        -- not
        if start = '1' then
          data_at_start <= data;
          started <= true;
        elsif done = '1' then
          started <= false;
        end if;

        -- Report error if data changed between start and done
        if started and done = '0' then
          print_err(data = data_at_start, IDENTIFIER, "Data changed between start and corresponding done:" 
                      & LF & to_hstring(data_at_start) & LF & to_hstring(data));
        end if;
      else  -- reset = 1
        if started then -- alert once per interrupted SD cycle
          print(IDENTIFIER, string'("Note that RESET occurred between a start and a done pulse."));
        end if;
        started <= false; -- No longer in a start-done cycle
      end if;
    end if;

  end process mon_proc;

  tcon_con : process
  begin
    while true loop
      -- Indicate we are not busy
      tcon_ack  <= 'Z';
      tcon_err  <= 'Z';
      tcon_data(tcon_data'high downto 0) <= (others => 'Z');

      -- wait for a request
      wait until tcon_req = '1';

      --Deassert ACK/ERR while busy
      tcon_ack <= '0';
      tcon_err <= '0';
      case to_integer(unsigned(tcon_addr)) is

        when REG_START_COUNT =>
          if tcon_rwn = '1' then
            tcon_data <= std_logic_vector(to_unsigned(state.get_start_count,
                                                      tcon_data'length));
          else
            state.reset_start_count;
          end if;

          tcon_ack <= '1';

        when REG_DONE_COUNT =>
          if tcon_rwn = '1' then
            tcon_data <= std_logic_vector(to_unsigned(state.get_done_count,
                                                      tcon_data'length));
          else
            state.reset_done_count;
          end if;

          tcon_ack <= '1';

        when REG_DELAY_COUNT =>
          if tcon_rwn = '1' then
            tcon_data <= std_logic_vector(to_unsigned(state.get_delay_count,
                                                      tcon_data'length));
          end if;

          tcon_ack <= '1';

        when REG_STATUS =>
          if tcon_rwn = '1' then
            tcon_data(0) <= to_stdlogic(state.is_delayed);
            tcon_data(tcon_data'high downto 1) <= (others => '0');
          end if;

          tcon_ack <= '1';

        when others =>
          tcon_err <= '1'; -- allows TCON to create an error message

      end case;

      -- Wait for the REQ to go away
      wait until tcon_req = '0';

    end loop;
  end process tcon_con;

end architecture rtl;
