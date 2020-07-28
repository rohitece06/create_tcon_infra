--------------------------------------------------------------------------------
-- COPYRIGHT (c) 2015-2018 Schweitzer Engineering Laboratories, Inc.
-- SEL Confidential
--
-- Description:  SAIF master/slave testbench module.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity tb_tcon_saif is
  generic
  (
    DATA_WIDTH    : integer;
    FLAG_WIDTH    : integer;
    COMMAND_FILE  : string;
    LOG_FILE      : string;
    FLOP_DELAY    : time  := 1 ps
  );
  port
  (
    --Tcon port
    tcon_req  : in    std_logic;
    tcon_ack  : out   std_logic := 'Z';
    tcon_err  : out   std_logic := 'Z';
    tcon_addr : in    std_logic_vector(31 downto 0);
    tcon_data : inout std_logic_vector(31 downto 0) := (others => 'Z');
    tcon_rwn  : in    std_logic;

    --SAIF port
    clk       : in    std_logic;
    rts_rtr   : out   std_logic := '0';
    cts_ctr   : in    std_logic;
    data      : inout std_logic_vector(DATA_WIDTH+FLAG_WIDTH-1 downto 0) := (others => 'Z');
    is_paused : out boolean;
    unpause   : in  boolean := FALSE
  );
end tb_tcon_saif;

library ieee;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.text_processing_pkg.all;

library std;
use std.textio.all;

library osvvm;
use osvvm.RandomPkg.all;

architecture behav of tb_tcon_saif is
  constant REG_SAIF_CON         : natural := 0;
  constant REG_SAIF_BURST_MIN   : natural := 1;
  constant REG_SAIF_BURST_MAX   : natural := 2;
  constant REG_SAIF_DELAY_MIN   : natural := 3;
  constant REG_SAIF_DELAY_MAX   : natural := 4;
  constant REG_SAIF_SEED        : natural := 5;
  constant REG_SAIF_READ_COUNT  : natural := 6;
  constant REG_SAIF_WRITE_COUNT : natural := 7;

  -- Command types
  type command_type is
  (
    CMD_BURST, -- Set the burst
    CMD_DELAY, -- Set the delay
    CMD_IDLE,  -- Idle a number of clocks
    CMD_SEED,  -- Set the global seed for rand nums
    CMD_PAUSE, -- Pause the command file
    CMD_READ,  -- Read via SAIF
    CMD_DATA   -- Raw data
  );

  type command_record is record
    command_str : line;
    command     : command_type;
  end record command_record;

  type commands_array is array(natural range <>) of command_record;

  type saif_state_t is protected
    impure function is_bus_paused return boolean;
    procedure pause_bus;
    procedure unpause_bus;

    -- Generate a burst/delay value
    impure function get_burst return natural;
    impure function get_delay return natural;

    -- Read-only attributes
    impure function get_line_number return natural;
    impure function get_read_count  return natural;
    impure function get_write_count return natural;

    -- Getters
    impure function get_min_burst return natural;
    impure function get_max_burst return natural;
    impure function get_min_delay return natural;
    impure function get_max_delay return natural;
    impure function get_seed return natural;

    -- Setters
    procedure set_burst(min : in natural; max : in natural);
    procedure set_delay(min : in natural; max : in natural);
    procedure set_seed(seed_arg : in natural);

    -- Incrementers
    procedure reset_line_number;
    procedure increment_line_number;
    procedure increment_read_count;
    procedure increment_write_count;
  end protected saif_state_t;

  type saif_state_t is protected body
    variable min_burst : natural  := 1;
    variable max_burst : natural  := 1;
    variable min_delay : natural  := 0;
    variable max_delay : natural  := 0;
    variable seed      : natural  := 2958847;
    variable bus_is_paused     : boolean  := false;

    variable random : boolean := false;

    variable burst_rand : RandomPType;
    variable delay_rand : RandomPType;

    variable line_number : natural  := 0;
    variable read_count  : natural  := 0;
    variable write_count : natural  := 0;

    impure function is_bus_paused return boolean is
    begin
      return bus_is_paused;
    end function is_bus_paused;

    procedure pause_bus is
    begin
      bus_is_paused := true;
    end procedure pause_bus;

    procedure unpause_bus is
    begin
      bus_is_paused := false;
    end procedure unpause_bus;

    impure function get_burst return natural is
      variable ret : natural := min_burst;
    begin
      if ( random ) then
        ret := burst_rand.RandInt(min_burst, max_burst);
      end if;

      return ret;
    end function get_burst;

    impure function get_delay return natural is
      variable ret : natural := min_delay;
    begin
      if ( random ) then
        ret := delay_rand.RandInt(min_delay, max_delay);
      end if;

      return ret;
    end function get_delay;

    impure function get_line_number return natural is
    begin
      return line_number;
    end function get_line_number;

    impure function get_read_count return natural is
    begin
      return read_count;
    end function get_read_count;

    impure function get_write_count return natural is
    begin
      return write_count;
    end function get_write_count;

    impure function get_min_burst return natural is
    begin
      return min_burst;
    end function get_min_burst;

    impure function get_max_burst return natural is
    begin
      return max_burst;
    end function get_max_burst;

    impure function get_min_delay return natural is
    begin
      return min_delay;
    end function get_min_delay;

    impure function get_max_delay return natural is
    begin
      return max_delay;
    end function get_max_delay;

    impure function get_seed return natural is
    begin
      return seed;
    end function get_seed;

    procedure set_burst(min : in natural; max : in natural) is
    begin
      assert min <= max
        report "ERROR:  Burst minimum greater than burst maximum." & integer'image(min) & " > " & integer'image(max)
        severity error;
      assert min > 0
        report "ERROR:  Minimum burst is 1."
        severity error;

      min_burst := min;
      max_burst := max;

      random := (min_burst /= max_burst) or (min_delay /= max_delay);
      if ( random ) then
        burst_rand.InitSeed(seed);
      end if;
    end procedure set_burst;

    procedure set_delay(min : in natural; max : in natural) is
    begin
      assert min <= max
        report "ERROR:  Delay minimum greater than delay maximum." & integer'image(min) & " > " & integer'image(max)
        severity error;
      min_delay := min;
      max_delay := max;

      random := (min_burst /= max_burst) or (min_delay /= max_delay);
      if ( random ) then
        delay_rand.InitSeed(seed);
      end if;
    end procedure set_delay;

    procedure set_seed(seed_arg : in natural) is
    begin
      seed := seed_arg;
    end procedure set_seed;

    procedure reset_line_number is
    begin
      line_number := 0;
    end procedure reset_line_number;

    procedure increment_line_number is
    begin
      line_number := line_number + 1;
    end procedure increment_line_number;

    procedure increment_read_count is
    begin
      read_count := read_count + 1;
    end procedure increment_read_count;

    procedure increment_write_count is
    begin
      write_count := write_count + 1;
    end procedure increment_write_count;

  end protected body saif_state_t;

  shared variable saif_state : saif_state_t;

  signal bus_is_paused : boolean := false;
  signal unpaused  : boolean := false;
  signal unpause_i : boolean; -- NR

begin
  is_paused <= bus_is_paused;
  main_loop : process is
    variable COMMANDS : commands_array(0 to 6) :=
    (
      (new string'("burst"), CMD_BURST),
      (new string'("delay"), CMD_DELAY),
      (new string'("idle"),  CMD_IDLE),
      (new string'("seed"),  CMD_SEED),
      (new string'("pause"), CMD_PAUSE),
      (new string'("read"),  CMD_READ),
      (new string'("data"),  CMD_DATA)
    );

    procedure extract_values(L        : inout line;
                             min_val  : inout natural;
                             max_val  : inout natural) is
      variable tmp_min  : natural := min_val;
      variable tmp_max  : natural := max_val;
      variable good     : boolean;
    begin
      -- Extract the first number.  This is the minimum size
      skip_whitespace(L);
      extract_num(L, tmp_min, good);
      assert good report "ERROR:  Burst command with no value." severity error;
      min_val := tmp_min;

      -- If there are more arguments, then it is a range of values.
      if ( L'length > 0 ) then
        skip_whitespace(L);
        extract_num(L, tmp_max, good);
        max_val := tmp_max;

      -- Otherwise, set the max and min the same
      else
        max_val := min_val;
      end if;

    end procedure extract_values;

    procedure process_command_file(file cmdf : text;
                                   file logf : text;
                                   state     : inout saif_state_t) is
      variable L           : line;
      variable command_str : line;
      variable outline     : line;

      variable cmd         : command_type;

      variable tmp_min     : natural;
      variable tmp_max     : natural;
      variable tmp_seed    : natural;

      variable num         : natural;

      variable found       : boolean;
      variable good        : boolean;

      variable burst_cnt   : natural := 0;
      variable delay_cnt   : natural := 0;

      variable data_var : std_logic_vector(DATA_WIDTH-1 downto 0);
      variable flag_var : std_logic_vector(FLAG_WIDTH-1 downto 0);
    begin
      while not(endfile(cmdf)) loop
        readline(cmdf, L);
        state.increment_line_number;

        -- Skip leading whitespace
        skip_whitespace(L);

        -- Ignore blank lines
        next when L'length = 0;

        -- Ignore comments
        next when L(L'left) = '#' or L(L'left) = ';';

        cmd := CMD_DATA;
        for i in COMMANDS'range loop
          find_and_remove_string(L, COMMANDS(i).command_str.all, found);
          if ( found ) then
            cmd := COMMANDS(i).command;
            exit;
          end if;
        end loop;

        case cmd is
          when CMD_BURST =>
            tmp_min  := state.get_min_burst;
            tmp_max  := state.get_max_burst;
            tmp_seed := state.get_seed;
            extract_values(L, tmp_min, tmp_max);
            state.set_burst(tmp_min, tmp_max);

          when CMD_DELAY =>
            tmp_min  := state.get_min_delay;
            tmp_max  := state.get_max_delay;
            tmp_seed := state.get_seed;
            extract_values(L, tmp_min, tmp_max);
            state.set_delay(tmp_min, tmp_max);

          when CMD_READ =>
            extract_num(L, num, good);

            -- If no value, then we read forever (essentially natural'high)
            if ( not(good) ) then
              num := natural'high;

            -- Otherwise, it should be greater than 0
            elsif ( num = 0 ) then
              report "WARNING:  Read length of 0 found.  No read done."
                severity warning;
            end if;

            while ( num > 0 ) loop
              if ( burst_cnt = 0 ) then
                -- Generate a delay count
                delay_cnt := state.get_delay;

                while delay_cnt > 0 loop
                  wait until rising_edge(clk);
                  delay_cnt := delay_cnt - 1;
                end loop;

                -- Generate a burst count
                burst_cnt := state.get_burst;
              end if;

              while (num > 0 and burst_cnt > 0 ) loop
                rts_rtr <= '1' after FLOP_DELAY;

                -- Wait for the transfer
                wait until ( rising_edge(clk) and cts_ctr = '1');
                saif_state.increment_read_count;

                -- Dump the dta
                hwrite(outline, data(DATA_WIDTH-1 downto 0));

                -- Then the flags
                for i in FLAG_WIDTH-1 downto 0 loop
                  write(outline, ' ');
                  write(outline, data(i+DATA_WIDTH));
                end loop;

                 -- Dump the line to the file
                 writeline(logf, outline);

                 burst_cnt := burst_cnt -1;
                 num       := num - 1;
              end loop;
              rts_rtr <= '0' after FLOP_DELAY;
            end loop;

          when CMD_DATA =>
            if ( burst_cnt = 0 ) then
              -- Generate a burst count
              delay_cnt := state.get_delay;
              while delay_cnt > 0 loop
                wait until rising_edge(clk);
                delay_cnt := delay_cnt - 1;
              end loop;

              burst_cnt := state.get_burst;
            end if;

            extract_num(L, data_var, good);
            assert good report "Bad command data " & to_hstring(data_var) severity error;

            for i in FLAG_WIDTH-1 downto 0 loop
              flag_var(i) := '0';
              skip_whitespace(L);
              if ( L'length > 0 ) then
                read(L, flag_var(i));
              end if;
            end loop;

            rts_rtr <= '1' after FLOP_DELAY;
            data    <= flag_var & data_var after FLOP_DELAY;
            wait until (rising_edge(clk) and cts_ctr = '1');
            rts_rtr <= '0' after FLOP_DELAY;
            data    <= (others => 'Z') after FLOP_DELAY;
            burst_cnt := burst_cnt - 1;
            saif_state.increment_write_count;

          when CMD_IDLE =>
            extract_num(L, num, good);
            assert good report "Bad command at idle " & integer'image(num)
              severity note;
            for i in 1 to num loop
              wait until rising_edge(clk);
            end loop;

          when CMD_SEED =>
            extract_num(L, num, good);
            assert good report "Bad command at seed " & integer'image(num)
              severity note;
            assert num > 0 report "ERROR: Seed must be greater than 0."
              severity error;
            saif_state.set_seed(num);

          when CMD_PAUSE =>
            saif_state.pause_bus;

            -- And stop processing the command file
            exit;

          when others =>
            report "ERROR:  Invalid command" severity error;

        end case;

        deallocate(L);
      end loop;
    end procedure process_command_file;

    file cmdf : text;
    file logf : text;

    variable status : file_open_status;
  begin
    -- Open the log file
    file_open(status, logf, LOG_FILE, write_mode);
    assert status = open_ok
      report "ERROR:  Unable to open log file: " & LOG_FILE
      severity error;

    loop
      file_open(status, cmdf, COMMAND_FILE, read_mode);
      assert status = open_ok
        report "ERROR:  Unable to open command file: " & COMMAND_FILE
        severity error;

      saif_state.reset_line_number;

      while not endfile(cmdf) loop
        process_command_file(cmdf, logf, saif_state);
        if ( saif_state.is_bus_paused ) then
          bus_is_paused <= true;
          if unpause then
            -- If unpause is already TRUE then skip
            null;
          else
            -- Wait for an event to happen on unpause or through the TCON bus
            wait until unpause_i;
          end if;
          bus_is_paused <= false;
          saif_state.unpause_bus;
        end if;
      end loop;

      -- Close the command file (so we can reopen again and start over)
      file_close(cmdf);
    end loop;
  end process;

  -- Internal signal is either the unpause input or the bit set by
  -- TCON bus register
  unpause_i <= unpause or unpaused;

  tcon_con : process
  begin
    while true loop
      -- Indicate we are not busy
      tcon_ack  <= 'Z';
      tcon_err  <= 'Z';
      tcon_data <= (others => 'Z');

      -- wait for a request
      wait until tcon_req = '1';

      --Deassert ACK/ERR while busy
      tcon_ack <= '0';
      tcon_err <= '0';
      case to_integer(unsigned(tcon_addr)) is
        when REG_SAIF_CON =>
          if(tcon_rwn = '0') then
            if ( tcon_data(0) = '1' ) then
              unpaused <= true;
              -- Allow one delta cycle to register the event
              wait until unpaused;
              unpaused <= false;
            end if;
          else
            tcon_data    <= (others => '0');
            tcon_data(0) <= '1' when bus_is_paused else '0';
          end if;

          tcon_ack <= '1';

        when REG_SAIF_BURST_MIN =>
          if(tcon_rwn = '0') then
            saif_state.set_burst(to_integer(unsigned(tcon_data)), saif_state.get_max_burst);
          else
            tcon_data <= std_logic_vector(to_unsigned(saif_state.get_min_burst, 32));
          end if;

          tcon_ack <= '1';

        when REG_SAIF_BURST_MAX =>
          if(tcon_rwn = '0') then
            saif_state.set_burst(saif_state.get_min_burst, to_integer(unsigned(tcon_data)));
          else
            tcon_data <= std_logic_vector(to_unsigned(saif_state.get_max_burst, 32));
          end if;

          tcon_ack <= '1';

        when REG_SAIF_DELAY_MIN =>
          if(tcon_rwn = '0') then
            saif_state.set_delay(to_integer(unsigned(tcon_data)), saif_state.get_max_delay);
          else
            tcon_data <= std_logic_vector(to_unsigned(saif_state.get_min_delay, 32));
          end if;

          tcon_ack <= '1';

        when REG_SAIF_DELAY_MAX =>
          if(tcon_rwn = '0') then
            saif_state.set_delay(saif_state.get_min_delay, to_integer(unsigned(tcon_data)));
          else
            tcon_data <= std_logic_vector(to_unsigned(saif_state.get_max_delay, 32));
          end if;

          tcon_ack <= '1';

        when REG_SAIF_SEED =>
          if(tcon_rwn = '0') then
            saif_state.set_seed(to_integer(unsigned(tcon_data(15 downto 0))));
          else
            tcon_data <= std_logic_vector(to_unsigned(saif_state.get_seed, 32));
          end if;

          tcon_ack <= '1';

        when REG_SAIF_READ_COUNT =>
          if(tcon_rwn = '1') then
            tcon_data <= std_logic_vector(to_unsigned(saif_state.get_read_count, 32));
          end if;

          tcon_ack <= '1';

        when REG_SAIF_WRITE_COUNT =>
          if(tcon_rwn = '1') then
            tcon_data <= std_logic_vector(to_unsigned(saif_state.get_write_count, 32));
          end if;

          tcon_ack <= '1';

        when others =>
          tcon_err <= '1';
      end case;

      -- Wait for the REQ to go away
      wait until tcon_req = '0';
    end loop;
  end process tcon_con;

end architecture behav;
