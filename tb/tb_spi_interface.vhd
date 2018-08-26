--------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:   17:47:34 02/18/2017
-- Design Name:
-- Module Name:   /home/thomas/riscv/lxp32soc/spi/tb_spi_interface.vhd
-- Project Name:  bonfire
-- Target Device:
-- Tool versions:
-- Description:
--
-- VHDL Test Bench Created by ISE for module: wb_spi_interface
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes:
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

USE ieee.numeric_std.ALL;

use work.txt_util.all;

ENTITY tb_spi_interface IS
END tb_spi_interface;

ARCHITECTURE behavior OF tb_spi_interface IS




   --Inputs
   signal clk_i : std_logic := '0';
   signal reset_i : std_logic := '0';
   signal slave_miso_i : std_logic := '0';
   signal wb_adr_in : std_logic_vector(4 downto 2) := (others => '0');
   signal wb_dat_in : std_logic_vector(31 downto 0) := (others => '0');
   signal wb_we_in : std_logic := '0';
   signal wb_cyc_in : std_logic := '0';
   signal wb_stb_in : std_logic := '0';

    --Outputs
   signal slave_cs_o : std_logic;
   signal slave_clk_o : std_logic;
   signal slave_mosi_o : std_logic;
   signal irq : std_logic;
   signal wb_dat_out : std_logic_vector(31 downto 0);
   signal wb_ack_out : std_logic;

    signal TbSimEnded : std_logic := '0';

   -- Clock period definitions
   constant clk_i_period : time := 10 ns;

BEGIN

  slave_miso_i <= slave_mosi_o; -- loop back

    -- Instantiate the Unit Under Test (UUT)
   uut: entity work.bonfire_spi
   --GENERIC MAP (
   
     --ADR_LOW  => wb_adr_in'low
   --)

   PORT MAP (
         
          spi_clk_i => clk_i,
          
          slave_cs_o => slave_cs_o,
          slave_clk_o => slave_clk_o,
          slave_mosi_o => slave_mosi_o,
          slave_miso_i => slave_miso_i,
          irq => irq,
          
          wb_clk_i => clk_i,
          wb_rst_i => reset_i,
          wb_adr_in => wb_adr_in,
          wb_dat_in => wb_dat_in,
          wb_dat_out => wb_dat_out,
          wb_we_in => wb_we_in,
          wb_cyc_in => wb_cyc_in,
          wb_stb_in => wb_stb_in,
          wb_ack_out => wb_ack_out
        );


     -- Clock generation
     clk_i <= not clk_i after clk_i_period/2 when TbSimEnded /= '1' else '0';



   -- Stimulus process
   stim_proc: process
       variable d,t : std_logic_vector(7 downto 0);
       procedure wb_write(address : in std_logic_vector(wb_adr_in'range); data : in std_logic_vector(7 downto 0)) is
         begin
            wb_adr_in <= address;
            wait until rising_edge(clk_i);
            wb_dat_in <= (others=> '0');
            wb_dat_in(7 downto 0) <= data;
            wb_we_in <= '1';
            wb_cyc_in <= '1';
            wb_stb_in <= '1';

            wait  until rising_edge(clk_i) and wb_ack_out = '1' ;
            wb_stb_in <= '0';
            wb_cyc_in <= '0';

        end procedure;

       procedure wb_read(address : in std_logic_vector(wb_adr_in'range);
                          data: out std_logic_vector(7 downto 0) )  is
         begin
            wb_adr_in <= address;
            wait until rising_edge(clk_i);
            wb_we_in <= '1';
            wb_cyc_in <= '1';
            wb_stb_in <= '1';
            wb_we_in <= '0';
            wait until rising_edge(clk_i) and wb_ack_out = '1';
            data:= wb_dat_out(7 downto 0);
            wb_stb_in <= '0';
            wb_cyc_in <= '0';
           --wait for clk_period;
        end procedure;




   begin
      -- hold reset state for 100 ns.
      wait for 100 ns;

      wait for clk_i_period*10;

      print("Setting up Clock Divider");
      wb_write("100",X"01"); -- Clock Divider
      wb_read("100",d);
      print("Check Clock Divider: " & hstr(d));
      assert d = X"01"
        report "Clock divider set failure"
        severity failure;

      wb_write("000",X"FE"); -- Chip Select
      -- send 10 bytes without checking for receive
      for i in 1 to 10 loop
        wb_write("010",X"FF");
      end loop;
      wb_read("011",d); -- Dummy Read to sync
      
      -- Read/Write all 256 possible values of a byte
      for i in 0 to 255 loop
        t:=std_logic_vector(to_unsigned(i,t'length));
        wb_write("010",t);
        wb_read("011",d);
        print("Testing pattern: " & hstr(t) & " result: " & hstr(d));
        assert d = t
          report "Failure at pattern: " & hstr(t)
          severity failure;

      end loop;
      
      -- Dummy read, just to check that there is no deadlock
      for i in 1 to 10 loop
        wb_read("011",d);
      end loop;
      
      
      report "Success";
      tbSimEnded <= '1';

      wait;
   end process;

END;
