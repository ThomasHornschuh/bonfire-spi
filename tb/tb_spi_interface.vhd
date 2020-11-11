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
   signal wb_adr_in : std_logic_vector(15+2 downto 2) := (others => '0');
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

    signal cont_bus : boolean := false; -- When TRUE Wishbone bus cyles are executed without idle cycle in between

   -- Clock period definitions
   constant clk_i_period : time := 10 ns;

   constant clk_divider : natural := 1; --

BEGIN

  slave_miso_i <= slave_mosi_o; -- loop back

    -- Instantiate the Unit Under Test (UUT)
   uut: entity work.bonfire_spi
  --  GENERIC MAP (

  --    ADR_LOW  => wb_adr_in'low
  --  );

   PORT MAP (

          spi_clk_i => clk_i,

          slave_cs_o(0) => slave_cs_o,
          slave_clk_o(0) => slave_clk_o,
          slave_mosi_o(0) => slave_mosi_o,
          slave_miso_i(0) => slave_miso_i,
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
            if not cont_bus then
              wait until rising_edge(clk_i);
            end if;
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
            if not cont_bus then
              wait until rising_edge(clk_i);
            end if;
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


        procedure basic_test(lower:natural;upper:natural) is
        begin

          wb_write(X"0000",X"FE"); -- Chip Select and Auto wait mode
          for i in lower to upper loop
            t:=std_logic_vector(to_unsigned(i,t'length));
            wb_write(X"0002",t);
            wb_read(X"0003",d);
            print("Testing pattern: " & hstr(t) & " result: " & hstr(d));
            assert d = t
              report "Failure at pattern: " & hstr(t)
              severity failure;

          end loop;

        end procedure;

        procedure set_divider(clk_divider:natural) is
        variable div : std_logic_vector(7 downto 0);
        begin
           div:=std_logic_vector(to_unsigned(clk_divider-1,t'length));
           print("Setting up Clock Divider");
           wb_write(X"0004",div); -- Clock Divider
           wb_read(X"0004",d);
           print("Check Clock Divider: " & hstr(d));
           assert d = div
            report "Clock divider set failure"
            severity failure;

        end procedure;


        procedure test is
        begin


          set_divider(2);
          wb_write(X"0000",X"FE"); -- Chip Select
          -- send 4 bytes without checking for receive
          for i in 1 to 4 loop
            t:=std_logic_vector(to_unsigned(i,t'length));
            wb_write(X"0002",t);
          end loop;
          wb_read(X"0003",d); -- Dummy Read to sync

          basic_test(0,255);

          print("Test in non autowait mode");

          wb_write(X"0000",X"FC"); -- Switch off auto wait
          lw1: loop
              wb_read(X"0001",d);
              exit lw1 when d(0)='0';
          end loop;

          for i in 0 to 4 loop
            t:=std_logic_vector(to_unsigned(i,t'length));

            wb_write(X"0002",t);

            lw2: loop
              wb_read(X"0001",d);
              exit lw2 when d(0)='0';
            end loop;
            assert d(1)='1'
              report "Expected status_reg(1) be set"
              severity failure;

            wb_read(X"0003",d);
            print("Testing pattern: " & hstr(t) & " result: " & hstr(d));
            assert d = t
              report "Failure at pattern: " & hstr(t)
              severity failure;

            wb_read(X"0001",d);
            assert d(1)='0'
              report "Expected status_reg(1) be cleared"
              severity failure;

          end loop;

          print("Test different clock rates");
          set_divider(1); -- Lower extreme
          basic_test(0,255);
          set_divider(256); -- Upper extreme
          basic_test(250,255); -- Only a few bytes because of the slow clock

        end procedure;




   begin


      wait until rising_edge(clk_i); -- synchronize
      test;

      -- Repeat Test with continues Wishbone cycles
--      cont_bus<=true;
--      reset_i <= '1';
--      wait for clk_i_period * 5;
--      reset_i <= '0';
--      wait until rising_edge(clk_i); -- synchronize

--      test;


      report "Success";
      tbSimEnded <= '1';

      wait;
   end process;

END;
