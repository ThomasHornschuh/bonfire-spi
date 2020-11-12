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


  constant num_ports : natural := 2;
  subtype t_portrange is natural range 0 to NUM_PORTS-1;


  type t_resmap is array (t_portrange) of boolean;
  constant all_map : t_resmap := (others=>true);

  type t_testvector is array (0 to 3) of std_logic_vector(7 downto 0);

  constant test_vector : t_testvector := ( X"de",X"ad",X"be",X"ef");
   
   --Inputs
   signal clk_i : std_logic := '0';
   signal reset_i : std_logic := '0';
   signal slave_miso_i : std_logic_vector(num_ports-1 downto 0);
   signal wb_adr_in : std_logic_vector(7+2 downto 2) := (others => '0');
   signal wb_dat_in : std_logic_vector(31 downto 0) := (others => '0');
   signal wb_we_in : std_logic := '0';
   signal wb_cyc_in : std_logic := '0';
   signal wb_stb_in : std_logic := '0';

    --Outputs
   signal slave_cs_o : std_logic_vector(num_ports-1 downto 0);
   signal slave_clk_o : std_logic_vector(num_ports-1 downto 0);
   signal slave_mosi_o : std_logic_vector(num_ports-1 downto 0);
   signal irq : std_logic;
   signal wb_dat_out : std_logic_vector(31 downto 0);
   signal wb_ack_out : std_logic;

    signal TbSimEnded : std_logic := '0';

    signal cont_bus : boolean := false; -- When TRUE Wishbone bus cyles are executed without idle cycle in between

    signal res_map : t_resmap := (others=>false);

   -- Clock period definitions
   constant clk_i_period : time := 10 ns;

   constant clk_divider : natural := 1;

   procedure print_t( s:string ) is
    begin
      print(s &  " @ " & integer'image( now / 1 ns) & " ns" );
    end;

   function padr(portnum: natural; offset: std_logic_vector(3 downto 0)) return std_logic_vector is
   begin
      return std_logic_vector(to_unsigned(portnum,4)) & offset;
   end function;

BEGIN

  loopback: for i in t_portrange generate
    slave_miso_i(i) <= slave_mosi_o(i); -- loop back
  end generate;

    -- Instantiate the Unit Under Test (UUT)
  uut: entity work.bonfire_spi
  GENERIC MAP (
      NUM_PORTS => num_ports
  --    ADR_LOW  => wb_adr_in'low
  )
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

      procedure write_all_ports(offset:in std_logic_vector(3 downto 0);v: in std_logic_vector(7 downto 0)) is
      begin
        for p in t_portrange loop
          wb_write(padr(p,offset),v);
        end loop;
      end procedure;

      -- Run Basic loop test on all ports in paralell
      procedure basic_test(lower:natural;upper:natural) is
      begin

        write_all_ports(X"0",X"FE"); -- Chip Select and Auto wait mode

        for i in lower to upper loop
          t:=std_logic_vector(to_unsigned(i,t'length));
          write_all_ports(X"2",t);
          for p in t_portrange loop
              wb_read(padr(p,X"3"),d);
              print_t("Port: " & str(p) & " testing pattern: " & hstr(t) & " result: " & hstr(d));
              assert d = t
                report "Failure at pattern: " & hstr(t)
                severity failure;
          end loop;

        end loop;
        write_all_ports(X"0",X"FF"); -- deselect and Auto wait mode

      end procedure;

      procedure set_divider(portnum: natural; clk_divider:natural) is
      variable div : std_logic_vector(7 downto 0);
      begin
         div:=std_logic_vector(to_unsigned(clk_divider-1,t'length));
         print_t("Setting up Clock Divider for port:" & str(portnum));
         wb_write(padr(portnum,X"4"),div); -- Clock Divider
         wb_read(padr(portnum,X"4"),d);
         print_t("Check Clock Divider: " & hstr(d));
         assert d = div
          report "Clock divider set failure"
          severity failure;

      end procedure;


      procedure test is
     
      begin

        for p in t_portrange loop
          set_divider(p,2);
        end loop;
        basic_test(1,4);
       
        print_t("Test in non autowait mode");


        write_all_ports(X"0",X"FC"); -- Switch off auto wait
        -- wait until all ports are idle
        for p in t_portrange loop
          lw1: loop
              wb_read(padr(p,X"1"),d);
              exit lw1 when d(0)='0';
          end loop;
        end loop;
        -- Write/read 4 bytes without autowait
        for i in 0 to 3 loop
          res_map <= (others=>false);
          t:=test_vector(i);
          print_t("Write to all ports, pattern: " & hstr(t));
          write_all_ports(X"2",t); -- Write pattern to all ports in paralell
          while not (res_map = all_map) loop
            -- poll all port status registers round robin
            for p in t_portrange loop
              if not res_map(p) then
                --print_t("Checking port: " & str(p));
                wb_read(padr(p,X"1"),d);
                if d(0)='0' then
                    --print_t("reading port: " & str(p));
                    res_map(p) <= true; -- mark port ready
                    assert d(1)='1'
                      report "Expected status_reg(1) be set"
                      severity failure;

                    wb_read(padr(p,X"3"),d);
                    print_t("Port " & str(p) & " Testing pattern: " & hstr(t) & " result: " & hstr(d));
                    assert d = t
                        report "Failure at pattern: " & hstr(t)
                        severity failure;

                    wb_read(padr(p,X"1"),d);
                    assert d(1)='0'
                      report "Expected status_reg(1) be cleared"
                      severity failure;

                end if;
              end if;  
            end loop;
          end loop;
        end loop;

        print_t("Test different clock rates");
        set_divider(0,1); -- Lower extreme
        basic_test(250,255);
        set_divider(0,256); -- Upper extreme
        basic_test(250,251); -- Only a few bytes because of the slow clock

      end procedure;


  begin

     wait until rising_edge(clk_i); -- synchronize
     test;

     print_t("**********Repeat Test with continues Wishbone cycles************");
     cont_bus<=true;
     reset_i <= '1';
     wait for clk_i_period * 5;
     reset_i <= '0';
     wait until rising_edge(clk_i); -- synchronize
     test;


    report "Success";
    tbSimEnded <= '1';

    wait;
  end process;

END;
