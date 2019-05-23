-------------------------------------------------------------------------------
-- COPYRIGHT (c) 2013-2017 Schweitzer Engineering Laboratories, Inc.
-- SEL Confidential
--
-- Description: SAIF Passthrough (Pipeline Stage) Component
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity saif_pipeline_stage is
  generic
  (
    DATA_WIDTH : integer range 1 to 1200;
    STAGE_TYPE : integer range 0 to 1
  );
  port
  (
    clk        : in  std_logic;
    reset      : in  std_logic;

    data_in    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    ctr_in     : in  std_logic;
    rtr_out    : out std_logic; -- NR

    data_out   : out std_logic_vector(DATA_WIDTH-1 downto 0):= (others=>'0');
    rts_out    : out std_logic; -- NR
    cts_in     : in  std_logic
  );
end entity saif_pipeline_stage;


-----------------------------------------------------
--Component declaration
-----------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

package saif_pipeline_stage_pkg is

  component saif_pipeline_stage
  generic
  (
    DATA_WIDTH : integer range 1 to 1200;
    STAGE_TYPE : integer range 0 to 1
  );
  port
  (
    clk        : in  std_logic;
    reset      : in  std_logic;
    data_in    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    ctr_in     : in  std_logic;
    rtr_out    : out std_logic;
    data_out   : out std_logic_vector(DATA_WIDTH-1 downto 0);
    rts_out    : out std_logic;
    cts_in     : in  std_logic
  );
  end component;
end;


architecture rtl of saif_pipeline_stage is 

  signal full_r     : std_logic := '0'; -- Output register has valid data
  signal room_r     : std_logic := '0'; -- Room has been promised
  signal overflwd   : std_logic := '0'; -- Emergency register has valid data
  signal data_oflw  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others=>'0');

  
begin
 
   -- No pipeline mode
  no_pipe_gen: if (STAGE_TYPE = 0) generate
    data_out <= data_in;
    rtr_out  <= cts_in;
    rts_out  <= ctr_in;
  end generate no_pipe_gen;
  
  -- Pipeline mode
  pipe_gen: if (STAGE_TYPE = 1) generate
    -- REGISTERING OUTPUT:
    -- Dual register method: ideally a saif register stage will isolate both the 
    -- ingress and egress sides without hurting throughput.  Highest throughput is 
    -- maintained by asserting RTR whenever it appears there will likely be room
    -- the following clock cycle.
    -- 
    -- The challenge of registering control signals like RTR is that if RTR is 
    -- registered, RTR cannot change, even if cts_in drops. The data MUST be 
    -- accepted in the next clock cycle.
    --
    -- So, this architecture registers incoming data, with a second register for 
    -- this overflow condition. If it overflows, data is held safely in the 
    -- data_oflw register, and no data may ingress until the registered data is 
    -- sent, and the overflow data is put into the outgoing datastream.
    

    rts_out <= full_r; -- registered, so reset won't clear it until next clk cycle.
    rtr_out <= room_r;


    register_proc : process (clk)
    begin
      if rising_edge(clk) then
    -- EXTERNAL status registers:
        room_r    <= (not full_r or cts_in) and not reset;
        full_r    <= ((room_r and ctr_in) or (full_r and not cts_in) 
                        or overflwd) and not reset;  -- ingr'd or not egr or oflwd

    -- INTERNAL status registers:
        overflwd  <= ((full_r and room_r and ctr_in)      -- data is ingressing...
                     or overflwd) and not (cts_in or reset); -- when cts=0 hits

    -- DATA registers:
        -- Tee a copy to overflow buffer since RTR is reg'd (can't pause incoming)
        if room_r='1' then
          data_oflw  <= data_in;
        end if;

        if cts_in='1' and overflwd='1' then  -- Clear overflow when cts_in asserts
          data_out   <= data_oflw;
        elsif cts_in='1' or full_r='0' then  -- Pass thru if room is available
          data_out   <= data_in;
        else  -- if halted/paused (cts=0) then
          NULL; -- keep last data_out value until cts='1'
        end if;

      end if;
    end process;
  end generate pipe_gen;
  
end rtl;
