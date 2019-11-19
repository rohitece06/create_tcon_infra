library ieee ;
use ieee.std_logic_1164.all;
use ieee.numeric_std;

-----------------------------------------------------

entity debounce is -- hello there
	generic ( DWIDTH : integer;
			  AWIDTH: integer range 1 to 10 := 3;
			  BASE: integer := 4;
			  GEN_STRING : string := "None";
			  GEN_SLV : std_logic_vector(3 downto 0)
			) ;
	port
	(
		clk         : in  std_logic  ;
		rst         : in  std_logic  ;
		max_count   : in  std_logic_vector(7 downto 0);

		irbs_addr    : in std_logic_vector(AWIDTH - 1 downto 0);
		irbs_rd	    : in std_logic;
		irbs_wr	    : in std_logic;
		irbs_ack	   : out std_logic;
		irbs_din     : in std_logic_vector(DWIDTH - 1 downto 0);
		irbs_dout    : out std_logic_vector(DWIDTH-1 downto 0);

		irbm_addr    : out std_logic_vector(AWIDTH - 1 downto 0);
		irbm_rd	    : out std_logic;
		irbm_wr	    : out std_logic;
		irbm_ack	    : in std_logic;
		irbm_busy	    : in std_logic;
		irbm_din     : in std_logic_vector(DWIDTH - 1 downto 0);
		irbm_dout    : out std_logic_vector(DWIDTH-1 downto 0);

		out_rts    : out std_logic; --NR
		out_cts    : in std_logic;
		out_dout   : out std_logic_vector(DWIDTH-1 downto 0);

		in_rtr    : out std_logic; --NR
		in_ctr    : in std_logic; --NR
		in_din    : in std_logic_vector(DWIDTH-1 downto 0);
		override_begin : in std_logic;

		edits_rtr    : out std_logic; --NR
		edits_ctr    : in std_logic; --NR
		edits_din    : in std_logic_vector(DWIDTH-1 downto 0);
		override_end : in std_logic;

		ext_rts    : out std_logic; --NR
		ext_cts    : in std_logic;
		ext_dout   : out std_logic_vector(DWIDTH-1 downto 0);
		ext_sof		 : out std_logic;
		ext_eof		 : out std_logic;
		ext_df		 : out std_logic;

		onem_start  	: out std_logic; --NR
		onem_done  	: in std_logic; --NR
		onem_data  	: out std_logic_vector(DWIDTH-1 downto 0); --NR

		tenk_start  	: in std_logic; --NR
		tenk_done  	: out std_logic; --NR
		tenk_data  	: in std_logic_vector(DWIDTH-1 downto 0); --NR

		serial_in  	: in  std_logic  ;
		serial_out 	: out std_logic;
		serial_out2 : out std_logic_vector(0 to 4) := (others => '0')
	);
end entity debounce;

-----------------------------------------------------

architecture FSM of debounce is

    type state_type is (S0, S1, S2, S3, S4);
    signal next_state, current_state: state_type;

begin

    state_reg: process(clock, max_count)
    begin

	if (max_count="00000000") then
            current_state <= S0;
	elsif (clock'event and clock='1') then
	    current_state <= next_state;
	end if;

    end process;

    comb_logic: process(current_state, serial_in)
    begin

	case current_state is

	    when S0 =>	serial_out <= '0';
			if serial_in='0' then
			    next_state <= S0;
			elsif serial_in ='1' then
			    next_state <= S1;
                            max_count <= "00000001";
			end if;

	    when S1 =>	serial_out <= '0';
			if serial_in='0' then
			    next_state <= S1;
                            max_count <= max_count + '1';
                            if (max_count >= "00000111") then
                                next_state <= S3;
                            end if;
			elsif serial_in='1' then
			    next_state <= S2;
                            max_count <= "00000001";
			end if;

	    when S2 =>	serial_out <= '0';
			if serial_in='0' then
			    next_state <= S2;
                            max_count <= max_count + '1';
                            if (unsigned(max_count) >= unsigned(max_count)/3) then
                                next_state <= S4;
                            end if;
			elsif serial_in='1' then
			    next_state <= S1;
                            max_count <= "00000001";
			end if;

	    when S3 =>	serial_out <= '1';
			next_state <= S0 -- For non overlapping sequence of '1'
            when S4 =>	serial_out <= '0';
			next_state <= S0 -- For non overlapping sequence of '0'
	    when others =>
			serial_out <= '0';
			next_state <= S0;

	end case;

    end process;

end FSM; -- file ends here
