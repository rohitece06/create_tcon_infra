-------------------------------------------------------------------------------
-- COPYRIGHT (c) 2013-2017 Schweitzer Engineering Laboratories, Inc.
-- SEL Confidential
--
-- Description: Test Bench for saif_pipeline_stage
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.saif_pipeline_stage_pkg.all;
use work.print_fnc_pkg.all;
use work.saif_master_pkg.all;
use work.saif_slave_pkg.all;
use std.textio.all; -- for line

entity saif_pipeline_stage_tb is
  generic
  (
    SAIF_BASE_FILENAME : string;
    D_WIDTH_STIM : integer range 1 to 1200;
    D_WIDTH_UUT : integer range 1 to 1200;
    STAGE_TYPE : integer range 0 to 1
  );
end saif_pipeline_stage_tb;

architecture behavioral of saif_pipeline_stage_tb is

  constant CLK_PERIOD : time := 8 ns;
  constant GARBAGE : std_logic_vector(31 downto 0) := x"10100101";

  signal clk : std_logic := '0';
  signal reset : std_logic := '0';

  signal rtr_out, rts_out, cts_in, ctr_in : std_logic := '0';
  signal s_m_done, s_s_done:boolean;
  signal data_from_m       :std_logic_vector(D_WIDTH_STIM-1 downto 0) := (others=>'0');
  signal data_into_uut     :std_logic_vector(D_WIDTH_UUT-1 downto 0) := (others=>'0');
  signal data_out_of_uut   :std_logic_vector(D_WIDTH_UUT-1 downto 0) := (others=>'0');
  signal data_out_of_helper:std_logic_vector(D_WIDTH_STIM-1 downto 0) := (others=>'0');
  signal data_to_s_slv     :std_logic_vector(D_WIDTH_STIM-1 downto 0) := (others=>'0');

    
begin
  timing_control : process
  begin
    -- LOCKUP PREVENTION
    -- Abort early if data is quiet for too long after a startup period:
    assert(not data_out_of_uut'stable(300*CLK_PERIOD) or now < (20*CLK_PERIOD))
      report "SIMULATION EXCEEDED TIME-LIMIT BEFORE COMPLETION -- LOCKED UP?"
        severity failure;


    if (s_m_done and s_s_done) = FALSE then -- wait a clock cycle:
      clk <= not clk;
      wait for clk_period/2;
    else
      clk <= not clk;
      wait for clk_period/2;
      wait;
    end if;
  end process;


  -- Count SAIF transfers and opportunities for transfers to detect degradation:
  throughput : process(clk)
    constant EXP_INGRESS_LATENCY : integer := STAGE_TYPE; -- expected delay for rtr
    variable ingress_delays, egress_delays : integer := 0;--expected throughput
    variable ingr_actual_cnt, egr_actual_cnt : integer := 0; --actual # words rcvd & sent by UUT
    variable wds_in_uut      : integer := 0; -- black-box expected UUT content
  begin
    if rising_edge(clk) then    -- Count events:
      -- expect 1 clock cycle latency due to the pipeline register
      if (STAGE_TYPE = 1) then
        -- Call egress delayed if cts and expected to have data:
        egress_delays := egress_delays + 1 when cts_in='1' and wds_in_uut /= 0;
        -- Call it delayed if ctr & expected to be empty/ing:
        ingress_delays := ingress_delays + 1 
          when ctr_in='1' and (wds_in_uut = 0 or cts_in='1');
        egr_actual_cnt :=  egr_actual_cnt + 1 when rts_out='1' and cts_in='1';
        ingr_actual_cnt := ingr_actual_cnt + 1 when rtr_out='1' and ctr_in='1';
        -- Assign wds_in_uut last so it won't be used until next clk cycle:
        wds_in_uut := 0            when reset='1' else
                      wds_in_uut   when ctr_in='1' and rtr_out='1' and cts_in='1' and rts_out='1' else
                      wds_in_uut+1 when ctr_in='1' and rtr_out='1' else
                      wds_in_uut-1 when cts_in='1' and rts_out='1';
      -- expect NO latency  
      elsif (STAGE_TYPE = 0) then
        -- Expect throughput increases when upper and down stream component are 
        -- both ready regardless of the component status
        egress_delays := egress_delays + 1 when cts_in='1' and ctr_in = '1' and reset = '0';
        ingress_delays := ingress_delays + 1 when ctr_in='1' and cts_in = '1' and reset = '0';
        -- Actual throughput increases when SAIF handshakings are done
        egr_actual_cnt :=  egr_actual_cnt + 1 when rts_out='1' and cts_in='1';
        ingr_actual_cnt := ingr_actual_cnt + 1 when rtr_out='1' and ctr_in='1';
      end if;
    end if;

    if s_s_done then
      assert(ingr_actual_cnt = ingress_delays - EXP_INGRESS_LATENCY
         and egr_actual_cnt = egress_delays)
        report "THROUGHPUT WAS DELAYED:"
        & ", ingress_delays:" & to_string(ingress_delays)
        & ", ingr_actual_cnt:" & to_string(ingr_actual_cnt)
        & ", expected ingr latency:" & to_string(egress_delays)
        & ", egress_delays:" & to_string(egress_delays)
        & ", egr_actual_cnt:" & to_string(egr_actual_cnt)
        & ", expected egress latency:" & to_string(0)
          severity error;
        -- Can test this by changing UUT code to: room_r <= (cts_in) and not reset;
    end if;
  end process;


  -- Provide SAIF stimulus data
  saif_m : saif_master
  generic map
  (
    D_WIDTH    => D_WIDTH_STIM,
    VERBOSE    => false,
    FILE_NAME  => SAIF_BASE_FILENAME & "--input.dat",
    IDENTIFIER => "SAIF Master"
  )
  port map
  (
    clk        => clk,
    rst        => reset,
    rts        => ctr_in,
    cts        => rtr_out,
    data       => data_from_m,
    done       => s_m_done,
    pass       => open
  );



  -- USE A SINGLE 32-BIT STIMULUS FILE TO TEST MULTIPLE DATA WIDTHS: ---------

  -- For WIDE DATA_WIDTH, feed saif_master data to lower bits of UUT:
  wide_d: if D_WIDTH_UUT >= D_WIDTH_STIM generate
  begin
      data_into_uut(D_WIDTH_STIM-1 downto 0) <= data_from_m -- put in what fits
          when ctr_in='1' else GARBAGE; -- pass garbage if not SAIF
      data_to_s_slv <= data_out_of_uut(D_WIDTH_STIM-1 downto 0);
  end generate;

  -- If DATA_WIDTH is smaller than the standard 32-bit, slice stim into two UUTs:
  narrow_d: if D_WIDTH_UUT < D_WIDTH_STIM generate
  begin
    data_into_uut <= data_from_m(D_WIDTH_UUT-1 downto 0);
    data_to_s_slv <= data_out_of_helper(D_WIDTH_STIM-1 downto D_WIDTH_UUT)
                      & data_out_of_uut(D_WIDTH_UUT-1 downto 0);
  end generate;


  -- Unit Under Test port map
  UUT : saif_pipeline_stage
  generic map
  (
    DATA_WIDTH => D_WIDTH_UUT,
    STAGE_TYPE => STAGE_TYPE
  )
  port map
  (
    clk => clk,
    reset => reset,
    rtr_out => rtr_out,
    ctr_in => ctr_in,
    data_in => data_into_uut,
    rts_out => rts_out,
    cts_in => cts_in,
    data_out => data_out_of_uut
  );


  -- Create a second pipeline stage for UUTs whose DATA_WIDTH can't fit all the
  -- data, so the saif_slave will still get all and be able to verify accuracy:
  tb_helper_pipe_stage : saif_pipeline_stage
  generic map
  (
    DATA_WIDTH => D_WIDTH_STIM,
    STAGE_TYPE => STAGE_TYPE
  )
  port map
  (
    clk => clk,
    reset => reset,
    rtr_out => open, -- relying on UUT
    ctr_in => ctr_in,
    data_in => data_from_m,
    rts_out => open, -- relying on UUT
    cts_in => cts_in,
    data_out => data_out_of_helper
  );


  saif_s : saif_slave
  generic map
  (
    D_WIDTH    => D_WIDTH_STIM,
    VERBOSE    => false,
    FILE_NAME  => SAIF_BASE_FILENAME & "--output.dat",
    IDENTIFIER => "SAIF Slave"
  )
  port map
  (
    clk        => clk,
    rtr        => cts_in,
    ctr        => rts_out,
    data       => data_to_s_slv,
    done       => s_s_done,
    pass       => open
  );


  -- Process to make "TB stimulus file commments" visible in waveform viewer:
  --   Won't show E comments, unfortunately (they are gone before the clk change)
  seeComments: process(clk)
    variable saif_m_comment : string(1 to 30):=(others=>'.');--long enough to see most
    variable saif_s_comment : string(1 to 30):=(others=>'.');--of comment in wave viewer
    variable comment_line   : line;
    variable chars2use      : integer;

  begin
    comment_line   := << variable saif_m.comment : line >>;
    saif_m_comment := (others=>'-'); -- clear old chars for waveform viewer
    chars2use      := minimum(comment_line.all'high, saif_m_comment'high) when comment_line /= NULL; -- match string size
    saif_m_comment(1 to chars2use) := comment_line.all(1 to chars2use) when comment_line /= NULL;

    comment_line   := << variable saif_s.comment : line >>;
    saif_s_comment := (others=>'-'); -- clear old chars for waveform viewer
    chars2use      := minimum(comment_line.all'high, saif_s_comment'high) when comment_line /= NULL; -- match string size
    saif_s_comment(1 to chars2use) := comment_line.all(1 to chars2use) when comment_line /= NULL; -- plot in waveform viewer
  end process;

end behavioral;
