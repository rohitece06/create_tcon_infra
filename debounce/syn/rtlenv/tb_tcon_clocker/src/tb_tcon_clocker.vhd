--------------------------------------------------------------------------------
-- COPYRIGHT (c) 2018 Schweitzer Engineering Laboratories, Inc.
-- SEL Confidential
--
-- Description:  Clock generation
--------------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

entity tb_tcon_clocker is
  generic
  (
    NUM_CLOCKS : natural
  );
  port
  (
    -- Tcon port
    tcon_req  : in    std_logic;
    tcon_ack  : out   std_logic := 'Z';
    tcon_err  : out   std_logic := 'Z';
    tcon_addr : in    std_logic_vector(31 downto 0);
    tcon_data : inout std_logic_vector(31 downto 0) := (others => 'Z');
    tcon_rwn  : in    std_logic;

    -- Clocks
    clks : out std_logic_vector(NUM_CLOCKS-1 downto 0) := (others => '0')
  );
end entity tb_tcon_clocker;

architecture behav of tb_tcon_clocker is

  constant NUM_CLK_REGS : natural := 4;

  constant CLK_DELAY : natural := 0;
  constant CLK_HIGH  : natural := 1;
  constant CLK_LOW   : natural := 2;
  constant CLK_CON   : natural := 3;

  constant MAX_ADDR  : natural := NUM_CLOCKS*NUM_CLK_REGS-1;

  subtype clk_idx is natural range 0 to NUM_CLOCKS-1;

  type clk_settings is protected
    procedure set_delay(clk : in natural; t : in natural);
    procedure set_low(clk   : in natural; t : in natural);
    procedure set_high(clk  : in natural; t : in natural);

    impure function get_delay(clk : natural) return natural;
    impure function get_low(clk   : natural) return natural;
    impure function get_high(clk  : natural) return natural;

    impure function get_state(clk : natural) return std_logic;
    procedure toggle(clk : in natural);

  end protected clk_settings;

  type clk_settings is protected body
    type settings_record is record
      delay  : time;
      high   : time;
      low    : time;
      state  : std_logic;
    end record settings_record;

    type settings_array is array(0 to NUM_CLOCKS-1) of settings_record;

    variable clk_set : settings_array := (others => (0 ps, 0 ps, 0 ps, '0'));

    -- Set the delay time (t, in ps) of the clk bit provided by the arg.
    procedure set_delay(clk : in natural; t : in natural) is
    begin
      clk_set(clk).delay := t * 1 ps;
    end procedure set_delay;

    -- Set the low time (t, in ps) of the clk bit provided by the arg.
    procedure set_low(clk   : in natural; t : in natural) is
    begin
      clk_set(clk).low := t * 1 ps;
    end procedure set_low;

    -- Set the high time (t, in ps) of the clk bit provided by the arg.
    procedure set_high(clk   : in natural; t : in natural) is
    begin
      clk_set(clk).high := t * 1 ps;
    end procedure set_high;

    -- Toggle the internal representation of the clk bit provided by the arg.
    procedure toggle(clk : in natural) is
    begin
      clk_set(clk).state := not(clk_set(clk).state);
    end procedure toggle;

    -- Get the delay time (in ps) of the clk bit provided by the arg.
    impure function get_delay(clk : natural) return natural is
    begin
      return clk_set(clk).delay / 1 ps;
    end function get_delay;

    -- Get the low time (in ps) of the clk bit provided by the arg.
    impure function get_low(clk   : natural) return natural is
    begin
      return clk_set(clk).low / 1 ps;
    end function get_low;

    -- Get the high time (in ps) of the clk bit provided by the arg.
    impure function get_high(clk   : natural) return natural is
    begin
      return clk_set(clk).high / 1 ps;
    end function get_high;

    -- Get the state of the clk bit provided by the arg.
    impure function get_state(clk : natural) return std_logic is
    begin
      return clk_set(clk).state;
    end function get_state;

  end protected body clk_settings;

  shared variable clk_set : clk_settings;

  type pause_array is array(0 to NUM_CLOCKS-1) of boolean;
  signal paused : pause_array := (others => true);

begin

  tcon_con : process
    variable idx : natural;
    variable reg : natural range 0 to NUM_CLK_REGS-1;
  begin
    while true loop
      -- Indicate we are not busy
      tcon_ack  <= 'Z';
      tcon_err  <= 'Z';
      tcon_data <= (others => 'Z');

      -- Wait for a request
      wait until tcon_req = '1';

      -- Deassert ACK/ERR while busy
      tcon_ack <= '0';
      tcon_err <= '0';

      -- Verify the requested address is adequate
      if ( to_integer(unsigned(tcon_addr)) > MAX_ADDR ) then
        tcon_err <= '1';
      else
        -- The selected clock is the address divided by the number of registers
        idx := to_integer(unsigned(tcon_addr)) / NUM_CLK_REGS;

        -- The selected register is the address module the number of registers
        reg := to_integer(unsigned(tcon_addr)) mod NUM_CLK_REGS;

        case reg is
          when CLK_DELAY =>
            if ( tcon_rwn = '0' ) then
              clk_set.set_delay(idx, to_integer(unsigned(tcon_data)));
            else
              tcon_data <= std_logic_vector(to_unsigned(clk_set.get_delay(idx), tcon_data'length));
            end if;

            -- Ack the access
            tcon_ack <= '1';
          when CLK_HIGH  =>
            if ( tcon_rwn = '0' ) then
              clk_set.set_high(idx, to_integer(unsigned(tcon_data)));
            else
              tcon_data <= std_logic_vector(to_unsigned(clk_set.get_high(idx), tcon_data'length));
            end if;

            -- Ack the access
            tcon_ack <= '1';
          when CLK_LOW   =>
            if ( tcon_rwn = '0' ) then
              clk_set.set_low(idx, to_integer(unsigned(tcon_data)));
            else
              tcon_data <= std_logic_vector(to_unsigned(clk_set.get_low(idx), tcon_data'length));
            end if;

            -- Ack the access
            tcon_ack <= '1';
          when CLK_CON   =>
            if ( tcon_rwn = '0' ) then
              paused(idx) <= (tcon_data(0) = '1');
            else
              tcon_data <= (others => '0');
              if ( paused(idx) ) then
                tcon_data(0) <= '1';
              end if;
            end if;

            -- Ack the access
            tcon_ack <= '1';

          when others    =>
            -- Invalid address is an error
            tcon_err <= '1';
        end case;
      end if;

      -- Wait for the REQ to go away
      wait until tcon_req = '0';
    end loop;
  end process tcon_con;

  clk_gen : for i in 0 to NUM_CLOCKS-1 generate
  begin
    clk_con : process
      variable last_time : time;
    begin
      -- Wait until unpaused
      wait until (not(paused(i)));

      -- Initialize the clock
      clks(i) <= clk_set.get_state(i);

      -- Wait for the delay period
      wait for clk_set.get_delay(i) * 1 ps;

      -- Loop while unpaused
      while not(paused(i)) loop
        -- Toggle the clock signal output
        clks(i) <= not(clk_set.get_state(i));

        -- Wait for the appropriate high/low time
        if ( clk_set.get_state(i) = '1' ) then
          wait for clk_set.get_low(i) * 1 ps;
        else
          wait for clk_set.get_high(i) * 1 ps;
        end if;

        -- Update the internal state of the clock
        -- after the appropriate wait time
        clk_set.toggle(i);

      end loop;
    end process clk_con;
  end generate clk_gen;
end architecture behav;
