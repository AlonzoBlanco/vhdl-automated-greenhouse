library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity entrada_digital_de10_lite is
    generic(
        CLK_HZ      : positive := 50000000;
        FILTRO_MS   : positive := 10;
        ACTIVO_BAJO : boolean  := true
    );
    port(
        clk        : in  std_logic;
        rst        : in  std_logic;

        entrada    : in  std_logic;
        salida_activa : out std_logic
    );
end entity;

architecture rtl of entrada_digital_de10_lite is

    constant FILTRO_MAX : natural := (CLK_HZ / 1000) * FILTRO_MS;

    signal sync_0       : std_logic := '0';
    signal sync_1       : std_logic := '0';
    signal entrada_norm : std_logic := '0';
    signal estado_r     : std_logic := '0';

    signal contador : natural range 0 to FILTRO_MAX := 0;

begin

    entrada_norm <= not sync_1 when ACTIVO_BAJO else sync_1;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sync_0   <= '0';
                sync_1   <= '0';
                estado_r <= '0';
                contador <= 0;
            else
                -- Sincronización a reloj de FPGA
                sync_0 <= entrada;
                sync_1 <= sync_0;

                -- Filtro simple para evitar cambios falsos
                if entrada_norm = estado_r then
                    contador <= 0;
                else
                    if contador = FILTRO_MAX then
                        estado_r <= entrada_norm;
                        contador <= 0;
                    else
                        contador <= contador + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    salida_activa <= estado_r;

end architecture;