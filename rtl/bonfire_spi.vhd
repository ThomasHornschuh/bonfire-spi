----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    25.08.2018
-- Design Name:
-- Module Name:
-- The Bonfire Processor Project, (c) 2018 Thomas Hornschuh
-- SPI Interface


-- registers:
-- base+0   -- control register
--             Bit 0: Slave_cs (TODO: Check polarity...)
--             Bit 1: 1 = Autowait mode (Bus Blocks until transfer is finished), set by Default
-- base+4   -- status register
--                bit 0:  1 = "transfer in progress"
--                bit 1:  1 = RX data avaliable, will be cleared after reading RX register
-- base+8   -- transmitter: write a byte here, starts SPI bus transaction
-- base+0x0C   -- receiver: last byte received (updated on each transation)
-- base+0x10   -- clock divider: SPI CLK is clk_i/2*(1+n) ie for 128MHz clock, divisor 0 is 64MHz, 1 is 32MHz, 3 is 16MHz etc


-- License: See LICENSE or LICENSE.txt File in git project root.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity bonfire_spi is
generic (

   CPOL : std_logic := '0';  -- SPI mode selection (mode 0 default)
   CPHA : std_logic := '0';  -- CPOL = clock polarity, CPHA = clock phase.
   SPI_2X_CLK_DIV : natural := 2;


   WB_DATA_WIDTH : natural :=32;
   ADR_LOW  : natural :=2
);
port (
      spi_clk_i : in std_logic;


      -- SPI Port:
      slave_cs_o         : out std_logic;
      slave_clk_o        : out std_logic;
      slave_mosi_o       : out std_logic;
      slave_miso_i       : in  std_logic;

      -- Interrupt signal:
      irq : out std_logic;

      -- Wishbone ports:
      wb_clk_i   : in std_logic;
      wb_rst_i   : in std_logic;
      wb_adr_in  : in  std_logic_vector(ADR_LOW+2 downto ADR_LOW);
      wb_dat_in  : in  std_logic_vector(WB_DATA_WIDTH-1 downto 0);
      wb_dat_out : out std_logic_vector(WB_DATA_WIDTH-1 downto 0);
      wb_we_in   : in  std_logic;
      wb_cyc_in  : in  std_logic;
      wb_stb_in  : in  std_logic;
      wb_ack_out : out std_logic
);
end bonfire_spi;

architecture rtl of bonfire_spi is

-- Attribute Infos for Xilinx Vivado IP Integrator Block designs
-- Should not have negative influence on other platforms.

ATTRIBUTE X_INTERFACE_INFO : STRING;
ATTRIBUTE X_INTERFACE_INFO of  wb_clk_i : SIGNAL is "xilinx.com:signal:clock:1.0 wb_clk_i CLK";
--X_INTERFACE_INFO of  wb_rst_i : SIGNAL is "xilinx.com:signal:reset:1.0 wb_rst_i RESET";

ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
ATTRIBUTE X_INTERFACE_PARAMETER of wb_clk_i : SIGNAL is "ASSOCIATED_BUSIF WB_SLAVE";
--ATTRIBUTE X_INTERFACE_PARAMETER of rst_i : SIGNAL is "ASSOCIATED_BUSIF WB_DB";

ATTRIBUTE X_INTERFACE_INFO OF wb_cyc_in: SIGNAL IS "bonfire.eu:wb:Wishbone_master:1.0 WB_SLAVE wb_dbus_cyc_o";
ATTRIBUTE X_INTERFACE_INFO OF wb_stb_in: SIGNAL IS "bonfire.eu:wb:Wishbone_master:1.0 WB_SLAVE wb_dbus_stb_o";
ATTRIBUTE X_INTERFACE_INFO OF wb_we_in: SIGNAL IS "bonfire.eu:wb:Wishbone_master:1.0  WB_SLAVE wb_dbus_we_o";
ATTRIBUTE X_INTERFACE_INFO OF wb_ack_out: SIGNAL IS "bonfire.eu:wb:Wishbone_master:1.0 WB_SLAVE wb_dbus_ack_i";
ATTRIBUTE X_INTERFACE_INFO OF wb_adr_in: SIGNAL IS "bonfire.eu:wb:Wishbone_master:1.0 WB_SLAVE wb_dbus_adr_o";
ATTRIBUTE X_INTERFACE_INFO OF wb_dat_in: SIGNAL IS "bonfire.eu:wb:Wishbone_master:1.0 WB_SLAVE wb_dbus_dat_o";
ATTRIBUTE X_INTERFACE_INFO OF wb_dat_out: SIGNAL IS "bonfire.eu:wb:Wishbone_master:1.0 WB_SLAVE wb_dbus_dat_i";


constant SPI_WORD_LEN : natural := 8;


subtype t_dbus is std_logic_vector(wb_dat_out'high downto wb_dat_out'low);

function fill_bits(v: std_logic_vector) return t_dbus is
   variable r : t_dbus;
   begin
     r(v'range):=v;
     r(r'high downto v'length) := (others=>'0');
     return r;
   end;

-- Register addresses


subtype t_adr is std_logic_vector(2 downto 0);

constant A_CTL_REG : t_adr := "000";
constant A_STATUS_REG : t_adr := "001";
constant A_TX_REG : t_adr := "010";
constant A_RX_REG : t_adr := "011";
constant A_CLK_REG :t_adr := "100";

-- --------------

signal rx_reg : std_logic_vector(SPI_WORD_LEN-1 downto 0);

signal m_do_valid_o, m_di_req_o, m_wren_ack : std_logic;
signal enable, req_read, req_write : std_logic;

signal m_wren_i : std_logic := '0';

signal tx_busy : std_logic := '0'; -- Transfer occuring
signal write_lock : std_logic := '0';

signal tx_reg : std_logic_vector(SPI_WORD_LEN-1 downto 0);


signal ctl_reg : std_logic_vector(1 downto 0) := "11";
signal status_reg : std_logic_vector(3 downto 0) :=(others=>'0');
signal clk_reg : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(SPI_2X_CLK_DIV-1,8));





begin

  slave_cs_o <= ctl_reg(0);

  enable <= wb_cyc_in and wb_stb_in;
  req_read <= enable and not wb_we_in;
  req_write <= enable and wb_we_in;

  ack: process(req_read,req_write, tx_busy,wb_adr_in,m_wren_i)
  begin

    if req_read='1' then
      if wb_adr_in=A_RX_REG then
        wb_ack_out <= not tx_busy;
      else
        wb_ack_out <= '1';
      end if;
    elsif req_write='1' then
      if wb_adr_in=A_TX_REG then
        wb_ack_out <= not tx_busy;
      else
        wb_ack_out <= '1';
      end if;
   else
     wb_ack_out <= '0';
   end if;

  end process;



  wb_dat_out <=
       fill_bits(rx_reg) when wb_adr_in = A_RX_REG else
       fill_bits(tx_reg) when wb_adr_in = A_TX_REG else
       fill_bits(ctl_reg) when wb_adr_in = A_CTL_REG else
       fill_bits(status_reg) when wb_adr_in = A_STATUS_REG else
       fill_bits(clk_reg) when wb_adr_in = A_CLK_REG else (others => 'X');


   --=============================================================================================
    -- Component instantiation for the SPI master port
    --=============================================================================================
    Inst_spi_master: entity work.spi_master(rtl)
        generic map (N => SPI_WORD_LEN, CPOL => CPOL, CPHA => CPHA)
        port map(
            sclk_i => spi_clk_i,                      -- system clock is used for serial and parallel ports
            pclk_i => wb_clk_i,
            rst_i => wb_rst_i,
            clk_div_i => clk_reg,
            spi_ssel_o => open,
            spi_sck_o => slave_clk_o,
            spi_mosi_o => slave_mosi_o,
            spi_miso_i => slave_miso_i,
            di_req_o => m_di_req_o,
            di_i => tx_reg,
            wren_i => m_wren_i,
            do_valid_o => m_do_valid_o,
            do_o => rx_reg,
            wr_ack_o => m_wren_ack

            ----- debug -----
            --do_transfer_o => m_do_transfer_o,
            --wren_o => m_wren_o,

            --rx_bit_reg_o => m_rx_bit_reg_o,

            --core_clk_o => m_core_clk_o,
            --core_n_clk_o => m_core_n_clk_o,
            --sh_reg_dbg_o => m_sh_reg_dbg_o
        );


    -- Auto wait mode and transaction ongoing
    tx_busy <= ctl_reg(1) and status_reg(0);


    process(wb_clk_i) is
    variable adr : t_adr; --required to have a "locally static" object for case statements

    begin
      adr:=wb_adr_in;
      if rising_edge(wb_clk_i) then

        if m_do_valid_o = '1' then
          status_reg(0) <= '0';
          status_reg(1) <= '1';
        end if;

        if m_wren_ack='1' then
          write_lock <= '0';
        end if;


        m_wren_i <= '0';

        if wb_rst_i='1' then
          ctl_reg <= "11";
          status_reg <= (others=>'0');
          clk_reg <= std_logic_vector(to_unsigned(SPI_2X_CLK_DIV-1,clk_reg'length));
          write_lock <= '0';
        elsif req_write='1'  then

          case adr is
            when A_TX_REG =>
              if  m_wren_ack='0' and write_lock='0' and tx_busy='0' then
                m_wren_i <='1';
                write_lock <= '1';
                status_reg(0) <= '1';
                tx_reg <= wb_dat_in(tx_reg'range);
              end if;

            when A_CTL_REG =>
              ctl_reg <= wb_dat_in(ctl_reg'range);
            when A_CLK_REG =>
              clk_reg <= wb_dat_in(clk_reg'range);
            when others => -- do nothing
          end case;
        elsif req_read='1' and adr= A_RX_REG then
          status_reg(1) <= '0';
        end if;
      end if;

    end process;


end rtl;

