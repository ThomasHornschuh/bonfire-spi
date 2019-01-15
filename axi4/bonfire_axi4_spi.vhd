----------------------------------------------------------------------------------

-- Module Name: bonfire_axi4_spi - Behavioral
-- The Bonfire Processor Project, (c) 2016,2017,2018 Thomas Hornschuh

-- Description:
-- AXI4/Xilinx IP Wrapper for bonfire_spi 
-- License: See LICENSE or LICENSE.txt File in git project root.
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;



entity bonfire_axi4_spi is
generic(
   ADRWIDTH  : integer := 15; -- Width of the AXI Address Bus, the Wishbone Adr- Bus coresponds with it, but without the lowest adress bits
   FAST_READ_TERM : boolean := TRUE; -- TRUE: Allows AXI read termination in same cycle as

   CPOL : std_logic := '0';  -- SPI mode selection (mode 0 default)
   CPHA : std_logic := '0';  -- CPOL = clock polarity, CPHA = clock phase.
   SPI_2X_CLK_DIV : natural := 2


);
 port (
   ---------------------------------------------------------------------------
   -- AXI Interface
   ---------------------------------------------------------------------------
   -- Clock and Reset
   S_AXI_ACLK    : in  std_logic;
   S_AXI_ARESETN : in  std_logic;
   -- Write Address Channel
   S_AXI_AWADDR  : in  std_logic_vector(ADRWIDTH-1 downto 0);
   S_AXI_AWVALID : in  std_logic;
   S_AXI_AWREADY : out std_logic;
   -- Write Data Channel
   S_AXI_WDATA   : in  std_logic_vector(31 downto 0);
   S_AXI_WSTRB   : in  std_logic_vector(3 downto 0);
   S_AXI_WVALID  : in  std_logic;
   S_AXI_WREADY  : out std_logic;
   -- Read Address Channel
   S_AXI_ARADDR  : in  std_logic_vector(ADRWIDTH-1 downto 0);
   S_AXI_ARVALID : in  std_logic;
   S_AXI_ARREADY : out std_logic;
   -- Read Data Channel
   S_AXI_RDATA   : out std_logic_vector(31 downto 0);
   S_AXI_RRESP   : out std_logic_vector(1 downto 0);
   S_AXI_RVALID  : out std_logic;
   S_AXI_RREADY  : in  std_logic;
   -- Write Response Channel
   S_AXI_BRESP   : out std_logic_vector(1 downto 0);
   S_AXI_BVALID  : out std_logic;
   S_AXI_BREADY  : in  std_logic;

   ---------------------------------------------------------------------------
   -- SPI Interface
   ---------------------------------------------------------------------------
   sclk_i     : in  std_logic; -- SPI Module System clock, can be asynchronous to S_AXI_ACLK

   -- SPI Ports are designed to be used in Xilinx Block Designs
   -- The Inteface layout is also suitable for QSPI and SPI Slave modes
   -- Nevertheless currently the interface is only used as SPI Master

   -- MOSI Pin
   io0_i : in std_logic; -- not used currently
   io0_o : out std_logic; -- MOSI Output
   io0_t : out std_logic; -- Always '0' currently

   -- MISO Pin
   io1_i : in std_logic;  -- MISO Input
   io1_o : out std_logic; -- not used currently
   io1_t : out std_logic; -- Always '1' currently

   -- SCLK Pin
   sck_i : in std_logic; -- not used currently
   sck_o : out std_logic;
   sck_t : out std_logic; -- Always '0' currently

   -- Slave Select (CS) pin
   --ss_i : in std_logic_vector(0 downto 0); -- not used currently
   ss_o : out std_logic_vector(0 downto 0); -- CS Output
   ss_t : out std_logic -- Always '1' currently

);
end bonfire_axi4_spi;


architecture Behavioral of bonfire_axi4_spi is



component bonfire_axi4l2wb is
generic (
    ADRWIDTH  : integer := 15; -- Width of the AXI Address Bus, the Wishbone Adr- Bus coresponds with it, but without the lowest adress bits
    FAST_READ_TERM : boolean := TRUE -- TRUE: Allows AXI read termination in same cycle as
    );
  port (
    S_AXI_ACLK : in STD_LOGIC;
    S_AXI_ARESETN : in STD_LOGIC;
    S_AXI_AWADDR : in STD_LOGIC_VECTOR ( ADRWIDTH-1 downto 0 );
    S_AXI_AWVALID : in STD_LOGIC;
    S_AXI_AWREADY : out STD_LOGIC;
    S_AXI_WDATA : in STD_LOGIC_VECTOR ( 31 downto 0 );
    S_AXI_WSTRB : in STD_LOGIC_VECTOR ( 3 downto 0 );
    S_AXI_WVALID : in STD_LOGIC;
    S_AXI_WREADY : out STD_LOGIC;
    S_AXI_ARADDR : in STD_LOGIC_VECTOR ( 14 downto 0 );
    S_AXI_ARVALID : in STD_LOGIC;
    S_AXI_ARREADY : out STD_LOGIC;
    S_AXI_RDATA : out STD_LOGIC_VECTOR ( 31 downto 0 );
    S_AXI_RRESP : out STD_LOGIC_VECTOR ( 1 downto 0 );
    S_AXI_RVALID : out STD_LOGIC;
    S_AXI_RREADY : in STD_LOGIC;
    S_AXI_BRESP : out STD_LOGIC_VECTOR ( 1 downto 0 );
    S_AXI_BVALID : out STD_LOGIC;
    S_AXI_BREADY : in STD_LOGIC;

    wb_clk_o : out STD_LOGIC;
    wb_rst_o : out STD_LOGIC;
    wb_addr_o : out STD_LOGIC_VECTOR ( ADRWIDTH-1 downto 2 );
    wb_dat_o : out STD_LOGIC_VECTOR ( 31 downto 0 );
    wb_we_o : out STD_LOGIC;
    wb_sel_o : out STD_LOGIC_VECTOR ( 3 downto 0 );
    wb_stb_o : out STD_LOGIC;
    wb_cyc_o : out STD_LOGIC;
    wb_dat_i : in STD_LOGIC_VECTOR ( 31 downto 0 );
    wb_ack_i : in STD_LOGIC
  );
  end component;


    component bonfire_spi
    generic (
      CPOL           : std_logic;
      CPHA           : std_logic;
      SPI_2X_CLK_DIV : natural := 2;
      WB_DATA_WIDTH  : natural := 32;
      ADR_LOW        : natural := 2
    );
    port (
      spi_clk_i     : in  std_logic;
      slave_cs_o   : out std_logic;
      slave_clk_o  : out std_logic;
      slave_mosi_o : out std_logic;
      slave_miso_i : in  std_logic;
      irq          : out std_logic;

      wb_clk_i     : in std_logic;
      wb_rst_i     : in  std_logic;
      wb_adr_in    : in  std_logic_vector(ADR_LOW+2 downto ADR_LOW);
      wb_dat_in    : in  std_logic_vector(WB_DATA_WIDTH-1 downto 0);
      wb_dat_out   : out std_logic_vector(WB_DATA_WIDTH-1 downto 0);
      wb_we_in     : in  std_logic;
      wb_cyc_in    : in  std_logic;
      wb_stb_in    : in  std_logic;
      wb_ack_out   : out std_logic
    );
    end component bonfire_spi;




    signal S_AXI_1_ARADDR : STD_LOGIC_VECTOR (ADRWIDTH-1 downto 0 );
    signal S_AXI_1_ARREADY : STD_LOGIC;
    signal S_AXI_1_ARVALID : STD_LOGIC;
    signal S_AXI_1_AWADDR : STD_LOGIC_VECTOR (ADRWIDTH-1 downto 0 );
    signal S_AXI_1_AWREADY : STD_LOGIC;
    signal S_AXI_1_AWVALID : STD_LOGIC;
    signal S_AXI_1_BREADY : STD_LOGIC;
    signal S_AXI_1_BRESP : STD_LOGIC_VECTOR ( 1 downto 0 );
    signal S_AXI_1_BVALID : STD_LOGIC;
    signal S_AXI_1_RDATA : STD_LOGIC_VECTOR ( 31 downto 0 );
    signal S_AXI_1_RREADY : STD_LOGIC;
    signal S_AXI_1_RRESP : STD_LOGIC_VECTOR ( 1 downto 0 );
    signal S_AXI_1_RVALID : STD_LOGIC;
    signal S_AXI_1_WDATA : STD_LOGIC_VECTOR ( 31 downto 0 );
    signal S_AXI_1_WREADY : STD_LOGIC;
    signal S_AXI_1_WSTRB : STD_LOGIC_VECTOR ( 3 downto 0 );
    signal S_AXI_1_WVALID : STD_LOGIC;
    signal S_AXI_ACLK_1 : STD_LOGIC;
    signal S_AXI_ARESETN_1 : STD_LOGIC;

    signal bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_ack_i : STD_LOGIC;
    signal bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_adr_o : STD_LOGIC_VECTOR ( 14 downto 2 );
    signal bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_cyc_o : STD_LOGIC;
    signal bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_dat_i : STD_LOGIC_VECTOR ( 31 downto 0 );
    signal bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_dat_o : STD_LOGIC_VECTOR ( 31 downto 0 );
    signal bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_stb_o : STD_LOGIC;
    signal bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_we_o : STD_LOGIC;
    signal bonfire_axi4l2wb_0_wb_clk_o : STD_LOGIC;
    signal bonfire_axi4l2wb_0_wb_rst_o : STD_LOGIC;


    signal spi_cs  :   std_logic;
    signal spi_clk  : std_logic;
    signal spi_mosi : std_logic;
    signal spi_miso :  std_logic;


-- Xilinx IP Integrator Attributes

    attribute X_INTERFACE_INFO : string;
    attribute X_INTERFACE_INFO of S_AXI_ACLK : signal is "xilinx.com:signal:clock:1.0 S_AXI_ACLK CLK";
    attribute X_INTERFACE_PARAMETER : string;
    attribute X_INTERFACE_PARAMETER of S_AXI_ACLK : signal is "XIL_INTERFACENAME S_AXI_ACLK, ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET S_AXI_ARESETN"; -- CLK_DOMAIN design_1_S_AXI_ACLK, FREQ_HZ 100000000, PHASE 0.000";
    attribute X_INTERFACE_INFO of S_AXI_ARESETN : signal is "xilinx.com:signal:reset:1.0 S_AXI_ARESETN RST";
    attribute X_INTERFACE_PARAMETER of S_AXI_ARESETN : signal is "XIL_INTERFACENAME S_AXI_ARESETN, POLARITY ACTIVE_LOW";


    attribute X_INTERFACE_INFO of S_AXI_arready : signal is "xilinx.com:interface:aximm:1.0 S_AXI ARREADY";
    attribute X_INTERFACE_INFO of S_AXI_arvalid : signal is "xilinx.com:interface:aximm:1.0 S_AXI ARVALID";
    attribute X_INTERFACE_INFO of S_AXI_awready : signal is "xilinx.com:interface:aximm:1.0 S_AXI AWREADY";
    attribute X_INTERFACE_INFO of S_AXI_awvalid : signal is "xilinx.com:interface:aximm:1.0 S_AXI AWVALID";
    attribute X_INTERFACE_INFO of S_AXI_bready : signal is "xilinx.com:interface:aximm:1.0 S_AXI BREADY";
    attribute X_INTERFACE_INFO of S_AXI_bvalid : signal is "xilinx.com:interface:aximm:1.0 S_AXI BVALID";
    attribute X_INTERFACE_INFO of S_AXI_rready : signal is "xilinx.com:interface:aximm:1.0 S_AXI RREADY";
    attribute X_INTERFACE_INFO of S_AXI_rvalid : signal is "xilinx.com:interface:aximm:1.0 S_AXI RVALID";
    attribute X_INTERFACE_INFO of S_AXI_wready : signal is "xilinx.com:interface:aximm:1.0 S_AXI WREADY";
    attribute X_INTERFACE_INFO of S_AXI_wvalid : signal is "xilinx.com:interface:aximm:1.0 S_AXI WVALID";
    attribute X_INTERFACE_INFO of S_AXI_araddr : signal is "xilinx.com:interface:aximm:1.0 S_AXI ARADDR";
    --attribute X_INTERFACE_PARAMETER of S_AXI_araddr : signal is "XIL_INTERFACENAME S_AXI, ADDR_WIDTH 16, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN design_1_S_AXI_ACLK, DATA_WIDTH 32, FREQ_HZ 100000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 1, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, MAX_BURST_LENGTH 1, NUM_READ_OUTSTANDING 1, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 1, NUM_WRITE_THREADS 1, PHASE 0.000, PROTOCOL AXI4LITE, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0";
    attribute X_INTERFACE_INFO of S_AXI_awaddr : signal is "xilinx.com:interface:aximm:1.0 S_AXI AWADDR";
    attribute X_INTERFACE_INFO of S_AXI_bresp : signal is "xilinx.com:interface:aximm:1.0 S_AXI BRESP";
    attribute X_INTERFACE_INFO of S_AXI_rdata : signal is "xilinx.com:interface:aximm:1.0 S_AXI RDATA";
    attribute X_INTERFACE_INFO of S_AXI_rresp : signal is "xilinx.com:interface:aximm:1.0 S_AXI RRESP";
    attribute X_INTERFACE_INFO of S_AXI_wdata : signal is "xilinx.com:interface:aximm:1.0 S_AXI WDATA";
    attribute X_INTERFACE_INFO of S_AXI_wstrb : signal is "xilinx.com:interface:aximm:1.0 S_AXI WSTRB";



    attribute X_INTERFACE_INFO of io0_i : signal is "xilinx.com:interface:spi:1.0 SPI_0 IO0_I";
    attribute X_INTERFACE_INFO of io0_t : signal is "xilinx.com:interface:spi:1.0 SPI_0 IO0_T";
    attribute X_INTERFACE_INFO of io0_o : signal is "xilinx.com:interface:spi:1.0 SPI_0 IO0_O";

    attribute X_INTERFACE_INFO of io1_i : signal is "xilinx.com:interface:spi:1.0 SPI_0 IO1_I";
    attribute X_INTERFACE_INFO of io1_o : signal is "xilinx.com:interface:spi:1.0 SPI_0 IO1_O";
    attribute X_INTERFACE_INFO of io1_t : signal is "xilinx.com:interface:spi:1.0 SPI_0 IO1_T";

    attribute X_INTERFACE_INFO of sck_i : signal is "xilinx.com:interface:spi:1.0 SPI_0 SCK_I";
    attribute X_INTERFACE_INFO of sck_o : signal is "xilinx.com:interface:spi:1.0 SPI_0 SCK_O";
    attribute X_INTERFACE_INFO of sck_t : signal is "xilinx.com:interface:spi:1.0 SPI_0 SCK_T";

--    --attribute X_INTERFACE_INFO of ss_i : signal is "xilinx.com:interface:spi:1.0 SPI_0 SS_I";
    attribute X_INTERFACE_INFO of ss_o : signal is "xilinx.com:interface:spi:1.0 SPI_0 SS_O";
    attribute X_INTERFACE_INFO of ss_t : signal is "xilinx.com:interface:spi:1.0 SPI_0 SS_T";
    
  --RIBUTE X_INTERFACE_PARAMETER OF io0_i: SIGNAL IS "XIL_INTERFACENAME SPI_0, XIL_NTERFACE_MODE MASTER, BOARD.ASSOCIATED_PARAM QSPI_BOARD_INTERFACE";
   attribute X_INTERFACE_INFO of sclk_i: signal is "xilinx.com:signal:clock:1.0 sclk_i CLK";
   attribute X_INTERFACE_PARAMETER of sclk_i: signal is "ASSOCIATED_BUSIF SPI_0";
    
begin

  S_AXI_1_ARADDR <= S_AXI_araddr;
  S_AXI_1_ARVALID <= S_AXI_arvalid;
  S_AXI_1_AWADDR <= S_AXI_awaddr;
  S_AXI_1_AWVALID <= S_AXI_awvalid;
  S_AXI_1_BREADY <= S_AXI_bready;
  S_AXI_1_RREADY <= S_AXI_rready;
  S_AXI_1_WDATA <= S_AXI_wdata;
  S_AXI_1_WSTRB<= S_AXI_wstrb;
  S_AXI_1_WVALID <= S_AXI_wvalid;
  S_AXI_ACLK_1 <= S_AXI_ACLK;
  S_AXI_ARESETN_1 <= S_AXI_ARESETN;
  S_AXI_arready <= S_AXI_1_ARREADY;
  S_AXI_awready <= S_AXI_1_AWREADY;
  S_AXI_bresp <= S_AXI_1_BRESP;
  S_AXI_bvalid <= S_AXI_1_BVALID;
  S_AXI_rdata <= S_AXI_1_RDATA;
  S_AXI_rresp <= S_AXI_1_RRESP;
  S_AXI_rvalid <= S_AXI_1_RVALID;
  S_AXI_wready <= S_AXI_1_WREADY;


  -- SPI Bus Wiring

  io0_t <= '0';
  io1_t <= '1';
  sck_t <= '0';
  ss_t <= '0';

  io0_o <= spi_mosi;
  spi_miso <= io1_i;
  sck_o <= spi_clk;

  ss_o(0) <= spi_cs;



  bonfire_axi4l2wb_0: component bonfire_axi4l2wb
       generic map (
         ADRWIDTH=>ADRWIDTH,
         FAST_READ_TERM=>FAST_READ_TERM
       )
       port map (
        S_AXI_ACLK => S_AXI_ACLK_1,
        S_AXI_ARADDR=> S_AXI_1_ARADDR,
        S_AXI_ARESETN => S_AXI_ARESETN_1,
        S_AXI_ARREADY => S_AXI_1_ARREADY,
        S_AXI_ARVALID => S_AXI_1_ARVALID,
        S_AXI_AWADDR => S_AXI_1_AWADDR,
        S_AXI_AWREADY => S_AXI_1_AWREADY,
        S_AXI_AWVALID => S_AXI_1_AWVALID,
        S_AXI_BREADY => S_AXI_1_BREADY,
        S_AXI_BRESP => S_AXI_1_BRESP,
        S_AXI_BVALID => S_AXI_1_BVALID,
        S_AXI_RDATA => S_AXI_1_RDATA,
        S_AXI_RREADY => S_AXI_1_RREADY,
        S_AXI_RRESP => S_AXI_1_RRESP,
        S_AXI_RVALID => S_AXI_1_RVALID,
        S_AXI_WDATA => S_AXI_1_WDATA,
        S_AXI_WREADY => S_AXI_1_WREADY,
        S_AXI_WSTRB => S_AXI_1_WSTRB,
        S_AXI_WVALID => S_AXI_1_WVALID,

        wb_ack_i => bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_ack_i,
        wb_addr_o=> bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_adr_o,
        wb_clk_o => bonfire_axi4l2wb_0_wb_clk_o,
        wb_cyc_o => bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_cyc_o,
        wb_dat_i => bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_dat_i,
        wb_dat_o => bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_dat_o,
        wb_rst_o => bonfire_axi4l2wb_0_wb_rst_o,
        --wb_sel_o(3 downto 0) => open,
        wb_stb_o => bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_stb_o,
        wb_we_o => bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_we_o
      );

  spi: component bonfire_spi
       generic map (
          CPOL => CPOL,
          CPHA => CPHA,
          SPI_2X_CLK_DIV => SPI_2X_CLK_DIV,
          WB_DATA_WIDTH =>32,
          ADR_LOW =>2

       )
       port map (


        wb_ack_out => bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_ack_i,
        wb_adr_in(4 downto 2) => bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_adr_o(4 downto 2),
        wb_clk_i => bonfire_axi4l2wb_0_wb_clk_o,
        wb_cyc_in => bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_cyc_o,
        wb_dat_in => bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_dat_o,
        wb_dat_out => bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_dat_i,
        wb_rst_i => bonfire_axi4l2wb_0_wb_rst_o,
        wb_stb_in => bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_stb_o,
        wb_we_in => bonfire_axi4l2wb_0_WB_MASTER_wb_dbus_we_o,

        slave_clk_o => spi_clk,
        slave_mosi_o => spi_mosi,
        slave_miso_i => spi_miso,
        slave_cs_o => spi_cs,
        
        spi_clk_i => sclk_i
        

      );

end Behavioral;
