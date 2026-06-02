library ieee;
use ieee.std_logic_1164.all;

entity fc37_lluvia_de10 is
    generic(
        CLK_HZ          : positive := 50000000;
        FILTRO_MS       : positive := 10;
        DO_ACTIVO_BAJO  : boolean  := true
    );
    port(
        clk              : in  std_logic;
        rst              : in  std_logic;

        fc37_do          : in  std_logic;

        lluvia_detectada : out std_logic
    );
end entity;

architecture rtl of fc37_lluvia_de10 is
begin

    u_filtro : entity work.entrada_digital_de10_lite
        generic map(
            CLK_HZ      => CLK_HZ,
            FILTRO_MS   => FILTRO_MS,
            ACTIVO_BAJO => DO_ACTIVO_BAJO
        )
        port map(
            clk           => clk,
            rst           => rst,
            entrada       => fc37_do,
            salida_activa => lluvia_detectada
        );

end architecture;