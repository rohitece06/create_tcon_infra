library ieee;
use ieee.std_logic_1164.all;

package tb_tcon_irb_slave_pkg is
  type access_mode_t    is (read, write);
  type write_priority_t is (tcon, irb);
  
  type region_param is record
    BASE_ADDRESS    : std_logic_vector; -- Base address of the region.
                                        -- Must have the same width as TCON/IRB
                                        -- address bus
    SIZE            : positive; -- Size, in words, of the region
    ACCESS_MODE     : access_mode_t;  -- Simultaneous access mode
    WRITE_PRIORITY  : write_priority_t; -- Simultaneous write priority
  end record region_param;

  type region_param_array is array (natural range <>) of region_param;
end package tb_tcon_irb_slave_pkg;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.tb_tcon_irb_slave_pkg.all;

entity tb_tcon_irb_slave is
  generic
  (
    REGION_PARAMS : region_param_array;
    DELAY_CLKS    : natural := 0;
    USE_BUSY      : boolean := true;
    FLOP_DELAY    : time := 1 ps
  );
  port
  (
    tcon_req  : in    std_logic;
    tcon_ack  : out   std_logic := 'Z';
    tcon_err  : out   std_logic := 'Z';
    tcon_addr : in    std_logic_vector;
    tcon_data : inout std_logic_vector;
    tcon_rwn  : in    std_logic;
    tcon_be   : in    std_logic_vector;

    irb_clk   : in  std_logic;
    irb_addr  : in  std_logic_vector;
    irb_di    : in  std_logic_vector;
    irb_do    : out std_logic_vector;
    irb_rd    : in  std_logic;
    irb_wr    : in  std_logic;
    irb_be    : in  std_logic_vector;
    irb_ack   : out std_logic := '0';
    irb_busy  : out std_logic := '0'
  );
begin
  -- Check the data width and address width of TCON and IRB interface
  assert tcon_data'length = irb_di'length
    report "TCON data width should match IRB data width" severity failure;

  assert irb_di'length = irb_do'length
    report "IRB data in width should match IRB data out" severity failure;

end entity tb_tcon_irb_slave;

architecture rtl of tb_tcon_irb_slave is 
  
  type memory is protected
    procedure read  ( 
                      constant addr : in std_logic_vector;
                      constant be   : in std_logic_vector;
                      variable data : out std_logic_vector
                    );
    procedure write (
                      constant addr : in std_logic_vector;
                      constant be   : in std_logic_vector;
                      constant data : in std_logic_vector
                    );


  end protected memory;

  type memory is protected body
    -- Example of memory mapping with the following REGION_PARAM definition
    -- REGION_PARAM(0): SIZE = 5, BASE_ADDR = 7. Region 1.
    -- REGION_PARAM(1): SIZE = 4, BASE_ADDR = 22. Region 2.
    -- REGION_PARAM(2): SIZE = 2, BASE_ADDR = 100. Region 3.
    -- The following show the virtual to physical memory mapping, where PA is
    -- physical address, VA is virtual address, and MR is memory region 
    -- 
    -- PA  |--0--|--1--|--2--|--3--|--4--|--5--|--6--|--7--|--8--|--9--|-10--|
    -- 
    -- VA: |--7--|--8--|--9--|-10--|-11--|-22--|-23--|-24--|-25--|-100-|-101-|
    --
    -- MR: |------------Reg 1------------|---------Reg 2---------|---Reg 3---|
    -- Of: |------------0----------------|-----------5-----------|-----9-----|
    -- To map from virtual address to physical address:
    -- + Subtract left from addr.
    -- + Then add the result with offset. 
    type mem_range is record
      -- Left and right use to find the correct memory region
      left    : natural;
      right   : natural;
      -- Offset of certain memory region in the big region
      offset  : natural;
    end record mem_range;
    type mem_range_array is array (0 to REGION_PARAMS'length - 1) of mem_range;
    
    variable is_initialized : boolean := FALSE;

    ----------------------------------------------------------------------------
    -- Get the range of each memory region. The left range would be base address
    -- and the right range would be base address plus the number of words minus
    -- one. The offset indicate the location of the base address on the physical
    -- memory
    ----------------------------------------------------------------------------
    function get_regions_range return mem_range_array is
      variable mem_range  : mem_range_array;
      variable offset     : natural := 0;
    begin
      for i in REGION_PARAMS'range loop
        mem_range(i).left   := to_integer(unsigned(REGION_PARAMS(i).BASE_ADDRESS));
        mem_range(i).right  := (to_integer(unsigned(REGION_PARAMS(i).BASE_ADDRESS)) +
                                REGION_PARAMS(i).SIZE - 1);
        mem_range(i).offset := offset;
        offset              := offset + REGION_PARAMS(i).SIZE;
      end loop;

      return mem_range;
    end function;

    constant MEM_REGION_RANGE: mem_range_array := get_regions_range;

    ----------------------------------------------------------------------------
    -- Get the total words of all memory regions
    ----------------------------------------------------------------------------
    function get_total_size return natural is
      variable total_mem_size : natural := 0;
    begin
      for i in REGION_PARAMS'range loop
        total_mem_size := total_mem_size + REGION_PARAMS(i).SIZE;
      end loop;

      return total_mem_size;
    end function;

    
    type memory_t is array (natural range <>) of std_logic_vector;
    variable memory_regions : memory_t(0 to (get_total_size)-1)(tcon_data'range);


    ----------------------------------------------------------------------------
    -- Find the region of certain address
    ----------------------------------------------------------------------------
    function get_region_number (constant addr : std_logic_vector) return integer is
      variable return_val : integer := -1;
    begin
      for i in MEM_REGION_RANGE'range loop
        if ((to_integer(unsigned(addr)) >= MEM_REGION_RANGE(i).left) and
            (to_integer(unsigned(addr)) <= MEM_REGION_RANGE(i).right)) then
              return_val := i;
        end if;
      end loop;

      if return_val = -1 then
        report "Invalid address" severity failure;
      end if;

      return return_val;
    end function get_region_number;

    ----------------------------------------------------------------------------
    -- Read from memory
    ----------------------------------------------------------------------------
    procedure read  ( 
                      constant addr : in std_logic_vector;
                      constant be   : in std_logic_vector;
                      variable data : out std_logic_vector
                    ) is
      constant REGION_NUMBER  : natural := get_region_number(addr);
      constant IDX            : natural := ((to_integer(unsigned(addr)) - 
                                            MEM_REGION_RANGE(REGION_NUMBER).left) +
                                            MEM_REGION_RANGE(REGION_NUMBER).offset);
      variable full_data      : std_logic_vector(data'range);
    begin
      full_data := memory_regions(IDX);

      -- If a byte is enabed, read the content, otherwise replace with 0.
      for i in be'range loop
        if be(i) = '1' then
          data(8*(i+1)-1 downto 8*i) := full_data(8*(i+1)-1 downto 8*i);
        else
          data(8*(i+1)-1 downto 8*i) := (others => '0');
        end if;
      end loop;
    end procedure read;

    ----------------------------------------------------------------------------
    -- Write to memory
    ----------------------------------------------------------------------------
    procedure write  (
                      constant addr : in std_logic_vector;
                      constant be   : in std_logic_vector;
                      constant data : in std_logic_vector
                    ) is
    
      constant REGION_NUMBER  : natural := get_region_number(addr);
      constant IDX            : natural := ((to_integer(unsigned(addr)) - 
                                              MEM_REGION_RANGE(REGION_NUMBER).left) +
                                              MEM_REGION_RANGE(REGION_NUMBER).offset);
      variable data_to_write  : std_logic_vector(data'range);            
    begin
      -- If a byte is enabled, write content. Otherwise replace with 0.
      for i in be'range loop
        if be(i) = '1' then
          data_to_write(8*(i+1)-1 downto 8*i) := data(8*(i+1)-1 downto 8*i);
        else
          data_to_write(8*(i+1)-1 downto 8*i) := (others => '0');
        end if;
      end loop;
      
      memory_regions(IDX) := data_to_write;

    end procedure write;
  end protected body memory;

  shared variable shared_memory : memory;
-- Architecture body
begin

  tcon_con : process
  variable tcon_addr_i  : std_logic_vector(tcon_addr'range);
  variable tcon_be_i    : std_logic_vector(tcon_be'range);
  variable tcon_data_i  : std_logic_vector(tcon_data'range);  

  begin
    while true loop
      -- Indicate we are not busy
      tcon_ack <= 'Z';
      tcon_err <= 'Z';
      tcon_data <= (tcon_data'range => 'Z');

      -- Wait for a request
      wait until tcon_req = '1';
      --Deassert ACK/ERR while busy
      tcon_ack <= '0';
      tcon_err <= '0';

      tcon_addr_i := tcon_addr;
      tcon_be_i   := tcon_be;
      tcon_data_i := tcon_data;

      -- Read operation
      if tcon_rwn = '1' then
        shared_memory.read(tcon_addr_i, tcon_be_i, tcon_data_i);
        tcon_data <= tcon_data_i;
      else -- Write operation
        shared_memory.write(tcon_addr_i, tcon_be_i, tcon_data_i);
      end if;

      tcon_ack <= '1';

      -- Wait for the REQ to go away
      wait until tcon_req = '0';
    end loop;
  end process tcon_con;

  irb_con : process
    variable irb_addr_i : std_logic_vector(irb_addr'range);
    variable irb_be_i   : std_logic_vector(irb_be'range);
    variable irb_di_i   : std_logic_vector(irb_di'range);
    variable irb_do_i   : std_logic_vector(irb_di'range);
  begin
    wait until rising_edge(irb_clk);

    irb_addr_i  := irb_addr;
    irb_be_i    := irb_be;
    irb_di_i    := irb_di;

    -- Reset the outputs
    irb_ack <= transport '0' after FLOP_DELAY;
    irb_busy <= transport '0' after FLOP_DELAY;

    if irb_rd = '1' then
      irb_do <= (irb_do'range => '0');
      shared_memory.read(irb_addr_i, irb_be_i, irb_do_i);

      if DELAY_CLKS > 0 then
        irb_do <= transport (irb_do'range => 'X') after FLOP_DELAY;
        for i in 1 to DELAY_CLKS loop
          wait until rising_edge(irb_clk);
        end loop;
      end if;

      irb_do  <= transport irb_do_i after FLOP_DELAY;
      irb_ack <= transport '1' after FLOP_DELAY;
    end if;

    if irb_wr = '1' then
      shared_memory.write(irb_addr_i, irb_be_i, irb_di_i);
      if USE_BUSY then
        irb_busy <= transport '1' after FLOP_DELAY;
      end if;

      if DELAY_CLKS > 0 then
        for i in 1 to DELAY_CLKS loop
          wait until rising_edge(irb_clk);
        end loop;
      end if;
      irb_busy <= transport '0' after FLOP_DELAY;
    end if;
  end process irb_con;
end architecture rtl;