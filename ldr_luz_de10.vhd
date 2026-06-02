library ieee;
use ieee.std_logic_1164.all;

entity ldr_luz_de10 is
    generic(
        CLK_HZ                 : positive := 50000000;
        FILTRO_MS              : positive := 10;
        DO_ACTIVO_BAJO_OSCURO  : boolean  := true
    );
    port(
        clk           : in  std_logic;
        rst           : in  std_logic;

        ldr_do        : in  std_logic;

        oscuro        : out std_logic;
        luz_detectada : out std_logic
    );
end entity;

architecture rtl of ldr_luz_de10 is

    signal oscuro_i : std_logic;

begin

    u_filtro : entity work.entrada_digital_de10_lite
        generic map(
            CLK_HZ      => CLK_HZ,
            FILTRO_MS   => FILTRO_MS,
            ACTIVO_BAJO => DO_ACTIVO_BAJO_OSCURO
        )
        port map(
            clk           => clk,
            rst           => rst,
            entrada       => ldr_do,
            salida_activa => oscuro_i
        );

    oscuro        <= oscuro_i;
    luz_detectada <= not oscuro_i;

end architecture;