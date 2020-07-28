--------------------------------------------------------------------------------
-- COPYRIGHT (c) 2018 Schweitzer Engineering Laboratories, Inc.
-- SEL Confidential
--
-- Description:  start done master testbench module.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.text_processing_pkg.all;

entity tb_tcon_start_done is
  generic
  (
    DIN_WIDTH       : integer;
    DIN_FLAG_WIDTH  : integer;
    DOUT_WIDTH      : integer;
    DOUT_FLAG_WIDTH : integer;
    COMMAND_FILE    : string;
    LOG_FILE        : string;
    FLOP_DELAY      : time := 1 ps
  );
  port
  (
    tcon_req  : in  std_logic;
    tcon_ack  : out std_logic := 'Z';
    tcon_err  : out std_logic := 'Z';
    tcon_addr : in    std_logic_vector(31 downto 0);
    tcon_data : inout std_logic_vector(31 downto 0) := (others => 'Z');
    tcon_rwn  : in    std_logic;

    clk       : in std_logic;
    reset     : in std_logic;
    start     : out std_logic := '0';
    done      : in std_logic;
    din       : in std_logic_vector(DIN_WIDTH+DIN_FLAG_WIDTH-1 downto 0);
    dout      : out std_logic_vector(DOUT_WIDTH+DOUT_FLAG_WIDTH-1 downto 0) 
                    := (others => 'Z');
    unpause   : in std_logic;
    is_paused : out boolean -- NR
  );
end tb_tcon_start_done;

library ieee;
use ieee.std_logic_1164.all;

package tb_tcon_start_done_pkg is
  component tb_tcon_start_done is
  generic
  (
    DIN_WIDTH       : integer;
    DIN_FLAG_WIDTH  : integer;
    DOUT_WIDTH      : integer;
    DOUT_FLAG_WIDTH : integer;
    COMMAND_FILE    : string;
    LOG_FILE        : string;
    FLOP_DELAY      : time := 1 ps
  );
  port
  (    
    tcon_req  : in  std_logic;
    tcon_ack  : out std_logic;
    tcon_err  : out std_logic;
    tcon_addr : in    std_logic_vector(31 downto 0);
    tcon_data : inout std_logic_vector(31 downto 0);
    tcon_rwn  : in    std_logic;

    clk       : in std_logic;
    reset     : in std_logic;
    start     : out std_logic;
    done      : in std_logic;
    din       : in std_logic_vector(DIN_WIDTH+DIN_FLAG_WIDTH-1 downto 0);
    dout      : out std_logic_vector(DOUT_WIDTH+DOUT_FLAG_WIDTH-1 downto 0);
    unpause   : in std_logic;
    is_paused : out boolean
  );
  end component tb_tcon_start_done;
end package tb_tcon_start_done_pkg;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.text_processing_pkg.all;

library std;
use std.textio.all;

library osvvm;
use osvvm.RandomPkg.all;

architecture behav of tb_tcon_start_done is

  constant REG_CON         : natural := 0;
  constant REG_BURST_MIN   : natural := 1;
  constant REG_BURST_MAX   : natural := 2;
  constant REG_DELAY_MIN   : natural := 3;
  constant REG_DELAY_MAX   : natural := 4;
  constant REG_SEED        : natural := 5;
  constant REG_START_COUNT : natural := 6;
  constant REG_DONE_COUNT  : natural := 7;
  constant REG_TIMEOUT     : natural := 8;
  constant REG_SEVERITY    : natural := 9;
  constant REG_DIN_COMP    : natural := 10; 

  -- This constant is used to dump invalid data
  -- into the log file.
  constant INVALID_DATA    : std_logic_vector(DIN_WIDTH+DIN_FLAG_WIDTH-1 downto 0)
                                                        := (others => 'X');

  -- Command types
  type command_type is
  (
    CMD_BURST,   -- Set the burst
    CMD_DELAY,   -- Set the delay
    CMD_IDLE,    -- Idle a number of clocks
    CMD_PAUSE,   -- Pause the command file
    CMD_TIMEOUT, -- Set the timeout
    CMD_SEED,    -- Set the seed value
    CMD_DATA     -- Raw data
  );

  type command_record is record
   command_str : line;
   command     : command_type;
  end record command_record;

  type commands_array is array(natural range <>) of command_record;

  type sd_state_t is protected

    ----------------------------------------------------------------------------
    -- Name : is_paused (function)
    -- Description : Provides the internal pause state of the component
    -- Inputs: None
    -- Returns : Boolean
    ----------------------------------------------------------------------------
    impure function is_paused return boolean;
    
    ----------------------------------------------------------------------------
    -- Name : pause (procedure)
    -- Description : Pauses the test component
    -- Inputs: None
    -- Outputs : None
    ----------------------------------------------------------------------------
    procedure pause;
    
    ----------------------------------------------------------------------------
    -- Name : unpause (procedure)
    -- Description : Unpauses the test component
    -- Inputs: None
    -- Outputs : None
    ----------------------------------------------------------------------------
    procedure unpause;
    
    ----------------------------------------------------------------------------
    -- Name : get_burst (function)
    -- Description : Returns the Burst Value
    -- Inputs: None
    -- Returns : Natural
    ----------------------------------------------------------------------------
    impure function get_burst return natural;
    
    ----------------------------------------------------------------------------
    -- Name : get_delay (function)
    -- Description : Returns the Delay Value
    -- Inputs: None
    -- Returns : Natural
    ----------------------------------------------------------------------------
    impure function get_delay return natural;

     -- Getters
    ----------------------------------------------------------------------------
    -- Name : get_start_count (function)
    -- Description : Returns the Start Count Variable
    -- Inputs: None
    -- Returns : Natural
    ----------------------------------------------------------------------------
    impure function get_start_count return natural;

    ----------------------------------------------------------------------------
    -- Name : get_done_count (function)
    -- Description : Returns the Done Count Variable
    -- Inputs: None
    -- Returns : Natural
    ----------------------------------------------------------------------------
    impure function get_done_count  return natural;

    ----------------------------------------------------------------------------
    -- Name : get_min_burst (function)
    -- Description : Returns the Minimum Burst Count Variable
    -- Inputs: None
    -- Returns : Natural
    ----------------------------------------------------------------------------
    impure function get_min_burst return natural;

    ----------------------------------------------------------------------------
    -- Name : get_max_burst (function)
    -- Description : Returns the Maximum Burst Count Variable
    -- Inputs: None
    -- Returns : Natural
    ----------------------------------------------------------------------------
    impure function get_max_burst return natural;
    
    ----------------------------------------------------------------------------
    -- Name : get_min_delay (function)
    -- Description : Returns the Minimum Delay Count Variable
    -- Inputs: None
    -- Returns : Natural
    ----------------------------------------------------------------------------
    impure function get_min_delay return natural;
    
    ----------------------------------------------------------------------------
    -- Name : get_max_delay (function)
    -- Description : Returns the Maximum Delay Count Variable
    -- Inputs: None
    -- Returns : Natural
    ----------------------------------------------------------------------------
    impure function get_max_delay return natural;
    
    ----------------------------------------------------------------------------
    -- Name : get_seed (function)
    -- Description : Returns the Seed Variable
    -- Inputs: None
    -- Returns : Natural
    ----------------------------------------------------------------------------
    impure function get_seed return natural;
    
    ----------------------------------------------------------------------------
    -- Name : get_timeout (function)
    -- Description : Returns the Timeout Variable
    -- Inputs: None
    -- Returns : Natural
    ----------------------------------------------------------------------------
    impure function get_timeout return natural;

    ----------------------------------------------------------------------------
    -- Name : get_severity (function)
    -- Description : Returns the Severity Variable
    -- Inputs: None
    -- Returns : Natural
    ----------------------------------------------------------------------------
    impure function get_severity return natural;
    
    ----------------------------------------------------------------------------
    -- Name : get_comp (function)
    -- Description : Returns the Compliance Variable
    -- Inputs: None
    -- Returns : Natural
    ----------------------------------------------------------------------------
    impure function get_comp     return natural; 

    -- Setters
    ----------------------------------------------------------------------------
    -- Name : set_burst (procedure)
    -- Description : Sets the minimum and maximum burst values
    -- Inputs: min - natural : The Minimum Burst to Set
    --         max - natural : The Maximum Burst to Set
    -- Outputs : None
    ----------------------------------------------------------------------------
    procedure set_burst(min : in natural; max : in natural);
    
    ----------------------------------------------------------------------------
    -- Name : set_delay (procedure)
    -- Description : Sets the minimum and maximum delay values
    -- Inputs: min - natural : The Minimum Delay to Set
    --         max - natural : The Maximum Delay to Set
    -- Outputs : None
    ----------------------------------------------------------------------------
    procedure set_delay(min : in natural; max : in natural);
    
    ----------------------------------------------------------------------------
    -- Name : set_seed (procedure)
    -- Description : Sets the seed value
    -- Inputs: seed_arg - natural : The Seed Value to Set
    -- Outputs : None
    ----------------------------------------------------------------------------
    procedure set_seed(seed_arg : in natural);
    
    ----------------------------------------------------------------------------
    -- Name : set_timeout (procedure)
    -- Description : Sets the timeout value
    -- Inputs: timeout_arg - natural : The Timeout Value to Set
    -- Outputs : None
    ----------------------------------------------------------------------------
    procedure set_timeout(timeout_arg : in natural);
    
    ----------------------------------------------------------------------------
    -- Name : set_severity (procedure)
    -- Description : Sets the severity value
    -- Inputs: severity_arg - natural : The Severity Value to Set
    -- Outputs : None
    ----------------------------------------------------------------------------
    procedure set_severity(severity_arg : in natural);
    
    ----------------------------------------------------------------------------
    -- Name : set_comp (procedure)
    -- Description : Sets the Compliance value, internally converts SLV to 
    --               integer
    -- Inputs: comp_arg - std_logic : The Severity Value to Set
    -- Outputs : None
    ----------------------------------------------------------------------------
    procedure set_comp(comp_arg : in std_logic);

    ----------------------------------------------------------------------------
    -- Name : reset_line_number (procedure)
    -- Description : Resets the current line number to the beginning
    -- Inputs : None
    -- Outputs : None
    ----------------------------------------------------------------------------
    procedure reset_line_number;

    ----------------------------------------------------------------------------
    -- Name : increment_line_number (procedure)
    -- Description : Increment the current line number by one
    -- Inputs : None
    -- Outputs : None
    ----------------------------------------------------------------------------
    procedure increment_line_number;
    
    ----------------------------------------------------------------------------
    -- Name : increment_start_count (procedure)
    -- Description : Increment the start count by one
    -- Inputs : None
    -- Outputs : None
    ----------------------------------------------------------------------------
    procedure increment_start_count;
    
    ----------------------------------------------------------------------------
    -- Name : reset_start_count (procedure)
    -- Description : Resets the start count to 0
    -- Inputs : None
    -- Outputs : None
    ----------------------------------------------------------------------------
    procedure reset_start_count;
    
    ----------------------------------------------------------------------------
    -- Name : increment_done_count (procedure)
    -- Description : Increment the done count by 1
    -- Inputs : None
    -- Outputs : None
    ----------------------------------------------------------------------------
    procedure increment_done_count;
    
    ----------------------------------------------------------------------------
    -- Name : reset_done_count (procedure)
    -- Description : Resets the done count to 0
    -- Inputs : None
    -- Outputs : None
    ----------------------------------------------------------------------------
    procedure reset_done_count;

  end protected sd_state_t;

  type sd_state_t is protected body
    variable min_burst   : natural  := 1;
    variable max_burst   : natural  := 1;
    variable min_delay   : natural  := 0;
    variable max_delay   : natural  := 0;
    variable seed        : natural  := 2958847;
    variable timeout     : natural  := 1;
    variable severity_var: natural  := 0;
    variable comp_var    : natural  := 0; 
    variable start_count : natural  := 0;
    variable done_count  : natural  := 0;
    variable paused      : boolean  := false;

    variable random : boolean := false;

    variable burst_rand : RandomPType;
    variable delay_rand : RandomPType;

    variable line_number : natural  := 0;

    impure function is_paused return boolean is
    begin
      return paused;
    end function is_paused;

    procedure pause is
    begin
      paused := true;
    end procedure pause;

    procedure unpause is
    begin
      paused := false;
    end procedure unpause;

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

    impure function get_start_count return natural is begin
      return start_count;
    end function get_start_count;

    impure function get_done_count return natural is begin
      return done_count;
    end function get_done_count;

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

    impure function get_timeout return natural is
    begin
      return timeout;
    end function get_timeout;

    impure function get_severity return natural is
    begin
      return severity_var;
    end function get_severity;

    impure function get_comp return natural is
    begin
      return comp_var;
    end function get_comp;


    procedure set_burst(min : in natural; max : in natural) is
    begin
      assert min <= max
        report "ERROR:  Burst minimum greater than burst maximum." & 
                integer'image(min) & " > " & integer'image(max)
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
        report "ERROR:  Delay minimum greater than delay maximum." 
                & integer'image(min) & " > " & integer'image(max)
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

    procedure set_timeout(timeout_arg : in natural) is
    begin
      timeout := timeout_arg;
    end procedure set_timeout;

    procedure set_severity(severity_arg : in natural) is
    begin
      severity_var := severity_arg;
    end procedure set_severity;

    procedure set_comp(comp_arg : in std_logic) is
    begin
      if comp_arg = '1' then
        comp_var := 1;
      else
        comp_var := 0;
      end if;
    end procedure set_comp;


    procedure reset_line_number is
    begin
      line_number := 0;
    end procedure reset_line_number;

    procedure increment_line_number is
    begin
      line_number := line_number + 1;
    end procedure increment_line_number;

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

  end protected body sd_state_t;

  shared variable sd_state : sd_state_t;

  signal start_i      : std_logic := '0';

  signal timed_out    : std_logic := '0';
  signal timed_out_d  : std_logic := '0';

  signal paused       : boolean := false;
  signal unpaused     : boolean := false;

  signal outside_cycle : std_logic := '1';
  signal oc_update     : stD_logic := '1';
  signal din_r         : std_logic_vector(din'range) := (others => '0'); 

begin

  is_paused <= transport paused after FLOP_DELAY;
  --connect internal signals to ports
  start <= transport start_i after FLOP_DELAY;

  main_loop : process is
    variable COMMANDS : commands_array(0 to 5) :=
    (
      (new string'("burst"), CMD_BURST),
      (new string'("delay"), CMD_DELAY),
      (new string'("idle"),  CMD_IDLE),
      (new string'("pause"), CMD_PAUSE),
      (new string'("timeout"), CMD_TIMEOUT),
      (new string'("seed"), CMD_SEED)
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

    procedure extract_seed(L        : inout line;
                             seed_val : inout natural) is
      variable tmp_seed : natural := seed_val;
      variable good     : boolean;
    begin
      -- The number is the tmp_seed
      skip_whitespace(L);
      extract_num(L, tmp_seed, good);
      if ( good ) then
        assert tmp_seed > 0 report "ERROR:  Seed must be greater than 0."
          severity error;
      end if;
      seed_val := tmp_seed;
    end procedure extract_seed;


    procedure extract_timeout_severity(L        : inout line;
                             timeout_val  : inout natural;
                             severity_val  : inout natural) is
      variable tmp_timeout   : natural := timeout_val;
      variable tmp_severity  : natural := severity_val;
      variable good     : boolean;
    begin
      -- Extract the first number.  This is the timeout value
      skip_whitespace(L);
      extract_num(L, tmp_timeout, good);
      assert good report "ERROR:  Timeout command with no value." severity error;
      timeout_val := tmp_timeout;

      -- If there are more arguments, then it is the severity value
      if ( L'length > 0 ) then
        skip_whitespace(L);
        extract_num(L, tmp_severity, good);
        severity_val := tmp_severity;
      end if;

    end procedure extract_timeout_severity;

    procedure process_command_file(file cmdf : text;
                                   file logf : text;
                                   state     : inout sd_state_t) is
      variable L           : line;
      variable command_str : line;
      variable outline     : line;

      variable cmd         : command_type;

      variable tmp_min     : natural;
      variable tmp_max     : natural;
      variable tmp_seed    : natural;

      variable tmp_timeout : natural;
      variable tmp_severity: natural;

      variable num         : natural;

      variable found       : boolean;
      variable good        : boolean;

      variable burst_cnt   : natural := 0;
      variable delay_cnt   : natural := 0;

      variable data_out    : std_logic_vector(DOUT_WIDTH-1 downto 0);
      variable out_flag_var: std_logic_vector(DOUT_FLAG_WIDTH-1 downto 0);
      variable in_flag_var : std_logic_vector(DIN_FLAG_WIDTH-1 downto 0);
      variable wait_done_cntr : integer;
    begin
      while not(endfile(cmdf)) loop
        if reset = '1' then
          wait until rising_edge(clk);
        else
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
              extract_values(L, tmp_min, tmp_max);
              state.set_burst(tmp_min, tmp_max);

            when CMD_DELAY =>
              tmp_min  := state.get_min_delay;
              tmp_max  := state.get_max_delay;
              extract_values(L, tmp_min, tmp_max);
              state.set_delay(tmp_min, tmp_max);

            when CMD_TIMEOUT =>
              tmp_timeout  := state.get_timeout;
              tmp_severity := state.get_severity;
              extract_timeout_severity(L, tmp_timeout, tmp_severity);
              state.set_timeout(tmp_timeout);
              state.set_severity(tmp_severity);

            when CMD_SEED =>
              tmp_seed := state.get_seed;
              extract_seed(L, tmp_seed);
              state.set_seed(tmp_seed);

            when CMD_DATA =>
              wait_done_cntr := 0;

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

              extract_num(L, data_out, good);
              assert good report "Bad command data " & to_hstring(data_out) severity error;

              for i in DOUT_FLAG_WIDTH-1 downto 0 loop
                out_flag_var(i) := '0';
                skip_whitespace(L);
                if ( L'length > 0 ) then
                  read(L, out_flag_var(i));
                end if;
              end loop;

              start_i <= '1';
              timed_out <= '0'; -- reset time out
              state.increment_start_count;
              dout <= transport out_flag_var & data_out after FLOP_DELAY;
              loop1 : loop
                wait until rising_edge(clk);
                start_i <= '0';
                wait_done_cntr := wait_done_cntr + 1;
                exit loop1 when done = '1' or wait_done_cntr = state.get_timeout+1 or reset = '1';
              end loop;

              dout <= (others => 'Z');

              if reset = '1' then
                report "Reset asserted in-between start-done transaction." 
                    severity note;
              elsif wait_done_cntr < state.get_timeout+1 then
                swrite(outline, "0x");
                -- done count is incremented only if it is not a time out.
                state.increment_done_count;
                -- Dump the data
                hwrite(outline, din(DIN_WIDTH-1 downto 0));
                 -- Then the flags
                for i in DIN_FLAG_WIDTH-1 downto 0 loop
                  write(outline, ' ');
                  write(outline, din(i+DIN_WIDTH));
                end loop;

                -- Dump the line to the file
                writeline(logf, outline);
              else
                swrite(outline, "0x");
                timed_out <= '1'; -- set timeout
                -- Dump the data as XXX...XXX X X X since done was not received
                hwrite(outline, INVALID_DATA(DIN_WIDTH-1 downto 0));
                 -- Then the flags
                for i in DIN_FLAG_WIDTH-1 downto 0 loop
                  write(outline, ' ');
                  write(outline, INVALID_DATA(i+DIN_WIDTH));
                end loop;

                -- Dump the line to the file
                writeline(logf, outline);

                -- assertions for severity
                assert state.get_severity /= 0 
                    report "Time out occurred. Done was not received."
                   severity failure;
                assert state.get_severity /= 1 report 
                    "Time out occurred. Done was not received."
                   severity error;
                assert state.get_severity /= 2 
                    report "Time out occurred. Done was not received."
                   severity warning;
                assert state.get_severity /= 3 
                    report "Time out occurred. Done was not received."
                   severity note;
              end if;

              burst_cnt := burst_cnt -1;

            when CMD_IDLE =>
              extract_num(L, num, good);
              assert good report "Bad command at idle " & integer'image(num) 
                severity note;
              for i in 1 to num loop
                wait until rising_edge(clk);
              end loop;

            when CMD_PAUSE =>
              -- if unpause is asserted, remain unpaused
              if unpause = '1' then
                sd_state.unpause;
              else
                sd_state.pause;
              end if;

              -- And stop processing the command file
              exit;

            when others =>
              report "ERROR:  Invalid command" severity error;

          end case;
        end if;
      end loop;
    end procedure process_command_file;

    file cmdf : text;
    file logf : text;

    variable status : file_open_status;
  begin -- main_loop
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

      sd_state.reset_line_number;

      while not endfile(cmdf) loop
        process_command_file(cmdf, logf, sd_state);
        if ( sd_state.is_paused ) then
          paused <= true;

          wait until (unpaused or unpause = '1'); 

          paused <= false;
          sd_state.unpause;
        end if;
      end loop;

      -- Close the command file (so we can reopen again and start over)
      file_close(cmdf);
    end loop;
  end process;

  -- assert to verify that 'done' does not assert without an expected 'start'
  done_trac_proc : process(clk)
    variable monitor_done : std_logic := '1';
  begin
    if rising_edge(clk) then
      timed_out_d <= timed_out;
      if (timed_out = '1' and timed_out_d = '0') then
        monitor_done := '1';
      elsif(start_i = '1' ) then
        monitor_done := '0';
      end if;

      assert monitor_done = '0' or done = '0'
        report "ERROR:  Unexpected Done occurred."  severity error;
    end if;
  end process done_trac_proc;

  oc_update <= outside_cycle and not start_i; 

  din_proc : process(clk, din) 
  begin
    if rising_edge(clk) then
      if reset = '1' then
        outside_cycle <= '0';
        din_r <= din; 
      else
        if done = '1' then
          outside_cycle <= '1';
          din_r <= din; 
        elsif start_i = '1' then
          outside_cycle <= '0'; 
        end if; 

        if (din_r /= din) and (oc_update = '1') then
          din_r <= din; 
          -- assertions for din compilance
          assert sd_state.get_comp/= 0 
            report "din changed outside of start/done cycle."
            severity error;
          assert sd_state.get_comp/= 1 
            report "din changed outside of start/done cycle."
            severity warning;            
        end if;
      end if;  
    end if;
  end process; 

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
        when REG_CON =>
          if(tcon_rwn = '0') then
            if ( tcon_data(0) = '1' ) then
              unpaused <= true;
              wait until unpaused;
              unpaused <= false;
            end if;
          else
            tcon_data    <= (others => '0');
            tcon_data(0) <= '1' when paused else '0';
          end if;

          tcon_ack <= '1';

        when REG_BURST_MIN =>
          if(tcon_rwn = '0') then
            sd_state.set_burst(to_integer(unsigned(tcon_data)), sd_state.get_max_burst);
          else
            tcon_data <= std_logic_vector(to_unsigned(sd_state.get_min_burst, 32));
          end if;

          tcon_ack <= '1';

        when REG_BURST_MAX =>
          if(tcon_rwn = '0') then
            sd_state.set_burst(sd_state.get_min_burst, to_integer(unsigned(tcon_data)));
          else
            tcon_data <= std_logic_vector(to_unsigned(sd_state.get_max_burst, 32));
          end if;

          tcon_ack <= '1';

        when REG_DELAY_MIN =>
          if(tcon_rwn = '0') then
            sd_state.set_delay(to_integer(unsigned(tcon_data)), sd_state.get_max_delay);
          else
            tcon_data <= std_logic_vector(to_unsigned(sd_state.get_min_delay, 32));
          end if;

          tcon_ack <= '1';

        when REG_DELAY_MAX =>
          if(tcon_rwn = '0') then
            sd_state.set_delay(sd_state.get_min_delay, to_integer(unsigned(tcon_data)));
          else
            tcon_data <= std_logic_vector(to_unsigned(sd_state.get_max_delay, 32));
          end if;

          tcon_ack <= '1';

        when REG_SEED =>
          if(tcon_rwn = '0') then
            sd_state.set_seed(to_integer(unsigned(tcon_data(15 downto 0))));
          else
            tcon_data <= std_logic_vector(to_unsigned(sd_state.get_seed, 32));
          end if;

          tcon_ack <= '1';

        when REG_START_COUNT =>
          if(tcon_rwn = '0') then
            sd_state.reset_start_count;
          else
            tcon_data <= std_logic_vector(to_unsigned(sd_state.get_start_count, 32));
          end if;

          tcon_ack <= '1';

        when REG_DONE_COUNT =>
          if(tcon_rwn = '0') then
            sd_state.reset_done_count;
          else
            tcon_data <= std_logic_vector(to_unsigned(sd_state.get_done_count, 32));
          end if;

          tcon_ack <= '1';

        when REG_TIMEOUT =>
          if(tcon_rwn = '0') then
            sd_state.set_timeout(to_integer(unsigned(tcon_data)));
          else
            tcon_data <= std_logic_vector(to_unsigned(sd_state.get_timeout, 32));
          end if;

          tcon_ack <= '1';

        when REG_SEVERITY =>
          if(tcon_rwn = '0') then
            sd_state.set_severity(to_integer(unsigned(tcon_data(2 downto 0))));
          else
            tcon_data <= std_logic_vector(to_unsigned(sd_state.get_severity, 32));
          end if;

          tcon_ack <= '1';


        when REG_DIN_COMP =>
          if(tcon_rwn = '0') then
            sd_state.set_comp(tcon_data(0));
          else 
            tcon_data <= std_logic_vector(to_unsigned(sd_state.get_comp, 32));
          end if;

          tcon_ack <= '1'; 

        when others =>
          tcon_err <= '1';
      end case;

      -- Wait for the REQ to go away
      wait until tcon_req = '0';
    end loop;
  end process tcon_con;
end architecture;
