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
   ADR_LOW  : natural :=2;
   NUM_PORTS : natural := 1
);
port (
      spi_clk_i : in std_logic;


      -- SPI Port:
      slave_cs_o         : out std_logic_vector(NUM_PORTS-1 downto 0);
      slave_clk_o        : out std_logic_vector(NUM_PORTS-1 downto 0);
      slave_mosi_o       : out std_logic_vector(NUM_PORTS-1 downto 0);
      slave_miso_i       : in  std_logic_vector(NUM_PORTS-1 downto 0);

      -- Interrupt signal:
      irq : out std_logic;

      -- Wishbone ports:
      wb_clk_i   : in std_logic;
      wb_rst_i   : in std_logic;
      wb_adr_in  : in  std_logic_vector(ADR_LOW+15 downto ADR_LOW);
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

subtype t_portrange is natural range 0 to NUM_PORTS-1;

-- Currently max. 16 Ports are supported. 
-- For every port 16 adresses are reserved (actually only 5 are used)
-- So, the lower 4 bits of the address select the register, the upper for select the port
subtype t_register_adr_range is natural range ADR_LOW+3 downto ADR_LOW;
subtype t_port_adr_range is natural range ADR_LOW+7 downto ADR_LOW+4;

subtype t_regadr is std_logic_vector(3 downto 0);  
subtype t_portadr is std_logic_vector(3 downto 0);

-- Register addresses
constant A_CTL_REG : t_regadr := "0000";
constant A_STATUS_REG : t_regadr := "0001";
constant A_TX_REG : t_regadr := "0010";
constant A_RX_REG : t_regadr := "0011";
constant A_CLK_REG :t_regadr := "0100";


subtype t_dbus is std_logic_vector(wb_dat_out'high downto wb_dat_out'low);

function fill_bits(v: std_logic_vector) return t_dbus is
   variable r : t_dbus;
   begin
     r(v'range):=v;
     r(r'high downto v'length) := (others=>'0');
     return r;
   end;


-- Address selectors
signal regadr : t_regadr;
signal portsel : t_portrange;


signal m_do_valid_o, m_di_req_o, m_wren_ack, m_wren_i : std_logic_vector(t_portrange);

signal enable, req_read, req_write : std_logic;

signal tx_busy : std_logic_vector(t_portrange); -- Transfer occuring
signal write_lock : std_logic_vector(t_portrange) := (others=>'0');

type t_word_reg is array (t_portrange) of std_logic_vector(SPI_WORD_LEN-1 downto 0);
type t_ctl_reg is array (t_portrange) of std_logic_vector(1 downto 0);
type t_status_reg is array (t_portrange) of std_logic_vector(3 downto 0);
type t_clk_reg is array (t_portrange) of std_logic_vector(7 downto 0);



-- Registers
signal rx_reg : t_word_reg;
signal tx_reg : t_word_reg;
signal ctl_reg :  t_ctl_reg := (others=> "11" );
signal status_reg : t_status_reg  := (others => (others => '0'));
signal clk_reg : t_clk_reg :=   (others=>  std_logic_vector(to_unsigned(SPI_2X_CLK_DIV-1,8)) );

component spi_master
Generic (
    N : positive := 32;                                             -- 32bit serial word length is default
    CPOL : std_logic := '0';                                        -- SPI mode selection (mode 0 default)
    CPHA : std_logic := '0';                                        -- CPOL = clock polarity, CPHA = clock phase.
    PREFETCH : positive := 2);                                       -- prefetch lookahead cycles
 --   SPI_2X_CLK_DIV : positive := 5);                                -- for a 100MHz sclk_i, yields a 10MHz SCK
Port (
    sclk_i : in std_logic := 'X';                                   -- high-speed serial interface system clock
    pclk_i : in std_logic := 'X';                                   -- high-speed parallel interface system clock
    rst_i : in std_logic := 'X';                                    -- reset core
    clk_div_i : std_logic_vector(7 downto 0);                  -- TH: Clock Divider

    ---- serial interface ----
    spi_ssel_o : out std_logic;                                     -- spi bus slave select line
    spi_sck_o : out std_logic;                                      -- spi bus sck
    spi_mosi_o : out std_logic;                                     -- spi bus mosi output
    spi_miso_i : in std_logic := 'X';                               -- spi bus spi_miso_i input
    ---- parallel interface ----
    di_req_o : out std_logic;                                       -- preload lookahead data request line
    di_i : in  std_logic_vector (N-1 downto 0) := (others => 'X');  -- parallel data in (clocked on rising spi_clk after last bit)
    wren_i : in std_logic := 'X';                                   -- user data write enable, starts transmission when interface is idle
    wr_ack_o : out std_logic;                                       -- write acknowledge
    do_valid_o : out std_logic;                                     -- do_o data valid signal, valid during one spi_clk rising edge.
    do_o : out  std_logic_vector (N-1 downto 0);                    -- parallel output (clocked on rising spi_clk after last bit)
    --- debug ports: can be removed or left unconnected for the application circuit ---
    sck_ena_o : out std_logic;                                      -- debug: internal sck enable signal
    sck_ena_ce_o : out std_logic;                                   -- debug: internal sck clock enable signal
    do_transfer_o : out std_logic;                                  -- debug: internal transfer driver
    wren_o : out std_logic;                                         -- debug: internal state of the wren_i pulse stretcher
    rx_bit_reg_o : out std_logic;                                   -- debug: internal rx bit
    state_dbg_o : out std_logic_vector (3 downto 0);                -- debug: internal state register
    core_clk_o : out std_logic;
    core_n_clk_o : out std_logic;
    core_ce_o : out std_logic;
    core_n_ce_o : out std_logic;
    sh_reg_dbg_o : out std_logic_vector (N-1 downto 0)              -- debug: internal shift register
);
end component spi_master;


begin

    regadr <= wb_adr_in(t_register_adr_range);
    portsel <= to_integer(unsigned( wb_adr_in(t_port_adr_range)));


    slave_cs_o <= ctl_reg(0);

    enable <= wb_cyc_in and wb_stb_in;
    req_read <= enable and not wb_we_in;
    req_write <= enable and wb_we_in;

  	ack: process(req_read,req_write, tx_busy,regadr,portsel)
  	begin

  	if req_read='1' then
  	  if regadr=A_RX_REG then
  		  wb_ack_out <= not tx_busy(portsel);
  	  else
  		  wb_ack_out <= '1';
  	  end if;
  	elsif req_write='1' then
  	  if regadr=A_TX_REG then
  		  wb_ack_out <= not tx_busy(portsel);
  	  else
  		  wb_ack_out <= '1';
  	  end if;
  	else
  	 wb_ack_out <= '0';
  	end if;

  	end process;



  wb_dat_out <=
       fill_bits(rx_reg(portsel)) when wb_adr_in = A_RX_REG else
       fill_bits(tx_reg(portsel)) when wb_adr_in = A_TX_REG else
       fill_bits(ctl_reg(portsel)) when wb_adr_in = A_CTL_REG else
       fill_bits(status_reg(portsel)) when wb_adr_in = A_STATUS_REG else
       fill_bits(clk_reg(portsel)) when wb_adr_in = A_CLK_REG else (others => 'X');


   --=============================================================================================
    -- Component instantiation for the SPI master port
    --=============================================================================================
    spi_masters: for i in t_portrange generate
      Inst_spi_master: spi_master
          generic map (N => SPI_WORD_LEN, CPOL => CPOL, CPHA => CPHA)
          port map(
              sclk_i => spi_clk_i,
              pclk_i => wb_clk_i,
              rst_i => wb_rst_i,

              clk_div_i => clk_reg(i),
              spi_ssel_o => open,
              spi_sck_o => slave_clk_o(i),
              spi_mosi_o => slave_mosi_o(i),
              spi_miso_i => slave_miso_i(i),
              di_req_o => m_di_req_o(i),
              di_i => tx_reg(i),
              wren_i => m_wren_i(i),
              do_valid_o => m_do_valid_o(i),
              do_o => rx_reg(i),
              wr_ack_o => m_wren_ack(i)
          );

          tx_busy(i) <= ctl_reg(i)(1) and status_reg(i)(0);

    end generate;    

    -- Auto wait mode and transaction ongoing
   


    process(wb_clk_i) is
   

    begin
      --adr:=wb_adr_in;
      if rising_edge(wb_clk_i) then

        for i in t_portrange loop
          if m_do_valid_o(i) = '1' then
            status_reg(i)(0) <= '0';
            status_reg(i)(1) <= '1';
          end if;

          if m_wren_ack(i)='1' then
            write_lock(i) <= '0';
          end if;
          m_wren_i(i) <= '0';
        end loop;  

        if wb_rst_i='1' then
          for i in t_portrange loop
            ctl_reg(i) <= "11";
            status_reg(i) <= (others=>'0');
            clk_reg(i) <= std_logic_vector(to_unsigned(SPI_2X_CLK_DIV-1,clk_reg'length));
            write_lock(i) <= '0';
          end loop;  
        elsif req_write='1'  then
          -- Bus write cycle
          case regadr is
            when A_TX_REG =>
              if  m_wren_ack(portsel)='0' and write_lock(portsel)='0' and tx_busy(portsel)='0' then
                m_wren_i(portsel) <='1';
                write_lock(portsel) <= '1';
                status_reg(portsel)(0) <= '1';
                tx_reg(portsel) <= wb_dat_in(tx_reg'range);
              end if;

            when A_CTL_REG =>
              ctl_reg(portsel) <= wb_dat_in(ctl_reg'range);
            when A_CLK_REG =>
              clk_reg(portsel) <= wb_dat_in(clk_reg'range);
            when others => -- do nothing
          end case;
        elsif req_read='1' and regadr=A_RX_REG then
          status_reg(portsel)(1) <= '0';
        end if;
      end if;

    end process;


end rtl;
