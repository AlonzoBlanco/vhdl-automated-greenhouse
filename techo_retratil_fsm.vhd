library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity techo_retratil_fsm is
    generic(
        -- Frecuencia base de la Intel DE10-Lite (50 MHz)
        CLK_HZ         : positive := 50000000; 
        -- Tiempo del temporizador en segundos para abrir/cerrar el techo
        MOTOR_TIME_SEC : positive := 5         
    );
    port(
        clk         : in  std_logic;
        rst         : in  std_logic; -- Reset asíncrono activo en ALTO

        -- Entradas de Sensores
        fc37_lluvia : in  std_logic; -- 1 = Lluvia detectada
        ldr_sol     : in  std_logic; -- 1 = Sol extremo detectado
        humedad_pct : in  natural range 0 to 100; -- Porcentaje ya procesado (0-100%)

        -- Salidas al Puente H (DRV8833)
        h_in1       : out std_logic;
        h_in2       : out std_logic;
        h_en_pwm    : out std_logic;

        -- Salidas a los Displays de 7 Segmentos (Ánodo común en DE10-Lite = Lógica Invertida)
        hex0        : out std_logic_vector(6 downto 0); -- Unidades
        hex1        : out std_logic_vector(6 downto 0); -- Decenas
        hex2        : out std_logic_vector(6 downto 0); -- Centenas
        hex3        : out std_logic_vector(6 downto 0)  -- Letra 'H'
    );
end entity;

architecture rtl of techo_retratil_fsm is

    -- Definición de Estados de la FSM
    type t_estado_fsm is (ST_REPOSO, ST_ABRIENDO, ST_CERRANDO);
    signal estado_actual : t_estado_fsm := ST_REPOSO;

    -- Memoria de la posición física para no activar el motor si ya está en posición
    type t_posicion is (DESCONOCIDO, CERRADO, ABIERTO);
    signal posicion_techo : t_posicion := DESCONOCIDO;

    -- Cálculo del tope del temporizador (50,000,000 * 5 = 250,000,000 ciclos)
    constant TIMER_MAX : natural := CLK_HZ * MOTOR_TIME_SEC;
    signal temporizador : natural range 0 to TIMER_MAX := 0;

    -- Función auxiliar para decodificar un dígito decimal a 7 segmentos (Lógica Invertida)
    function to_segs(digit : natural) return std_logic_vector is
        variable segs : std_logic_vector(6 downto 0);
    begin
        case digit is
            when 0 => segs := "1000000";
            when 1 => segs := "1111001";
            when 2 => segs := "0100100";
            when 3 => segs := "0110000";
            when 4 => segs := "0011001";
            when 5 => segs := "0010010";
            when 6 => segs := "0000010";
            when 7 => segs := "1111000";
            when 8 => segs := "0000000";
            when 9 => segs := "0010000";
            when others => segs := "1111111"; -- Apagado
        end case;
        return segs;
    end function;

begin

-------------------------------------------------------------------------
    -- PROCESO 1: Lógica de Control y FSM (Actualizado con 6 Casos)
    -------------------------------------------------------------------------
    proc_control_motor: process(clk, rst)
        variable condicion_cerrar : boolean;
        variable condicion_abrir  : boolean;
    begin
        -- Reset Asíncrono
        if rst = '1' then
            estado_actual  <= ST_REPOSO;
            posicion_techo <= DESCONOCIDO;
            temporizador   <= 0;
            
            -- Motor apagado por defecto
            h_in1    <= '0';
            h_in2    <= '0';
            h_en_pwm <= '0';

        elsif rising_edge(clk) then

            -- =====================================================================
            -- Evaluación Concurrente de las Reglas (Lógica de 6 Casos)
            -- =====================================================================
            
            -- Casos 1, 3 y 4: Cerrar el techo
            -- Se cierra si llueve y la tierra ya está húmeda (Caso 1)
            -- O si hay sol extremo y NO llueve (Casos 3 y 4)
            condicion_cerrar := (fc37_lluvia = '1' and humedad_pct >= 70) or 
                                (fc37_lluvia = '0' and ldr_sol = '1');
            
            -- Casos 2 y 5: Abrir el techo
            -- Se abre si la tierra está seca (humedad < 70%) Y 
            -- (está lloviendo para aprovechar el agua, o no hay sol extremo para ventilar)
            condicion_abrir  := (humedad_pct < 70) and 
                                (fc37_lluvia = '1' or ldr_sol = '0');
            
            -- Caso 6: Condiciones estables (Reposo)
            -- Si la humedad es >= 70%, no llueve y no hay sol extremo, ambas variables
            -- serán falsas y el sistema se quedará en ST_REPOSO sin hacer nada.
            -- =====================================================================

            case estado_actual is

                when ST_REPOSO =>
                    -- Detener el motor en reposo
                    h_in1    <= '0';
                    h_in2    <= '0';
                    h_en_pwm <= '0';
                    temporizador <= 0;

                    -- Transiciones de Estado comprobando que no estemos ya en esa posición
                    if condicion_cerrar and posicion_techo /= CERRADO then
                        estado_actual <= ST_CERRANDO;
                    elsif condicion_abrir and posicion_techo /= ABIERTO then
                        estado_actual <= ST_ABRIENDO;
                    end if;

                when ST_ABRIENDO =>
                    -- Giro del motor hacia adelante (Abrir)
                    h_in1    <= '1';
                    h_in2    <= '0';
                    h_en_pwm <= '1'; 

                    if temporizador = TIMER_MAX then
                        posicion_techo <= ABIERTO;
                        estado_actual  <= ST_REPOSO;
                    else
                        temporizador <= temporizador + 1;
                    end if;

                when ST_CERRANDO =>
                    -- Giro del motor en reversa (Cerrar)
                    h_in1    <= '0';
                    h_in2    <= '1';
                    h_en_pwm <= '1';

                    if temporizador = TIMER_MAX then
                        posicion_techo <= CERRADO;
                        estado_actual  <= ST_REPOSO;
                    else
                        temporizador <= temporizador + 1;
                    end if;

            end case;
        end if;
    end process proc_control_motor;

    -------------------------------------------------------------------------
    -- PROCESO 2: Visualización en Displays de 7 Segmentos
    -------------------------------------------------------------------------
    bcd_a_7segmentos: process(humedad_pct)
        variable centenas : natural := 0;
        variable decenas  : natural := 0;
        variable unidades : natural := 0;
    begin
        -- Descomposición de la humedad (0-100) en BCD para los displays
        if humedad_pct >= 100 then
            centenas := 1;
            decenas  := 0;
            unidades := 0;
        else
            centenas := 0;
            decenas  := humedad_pct / 10;
            unidades := humedad_pct mod 10;
        end if;

        -- Asignación a los displays (se invoca la función para el mapeo a cátodos/ánodos)
        hex2 <= to_segs(centenas);
        hex1 <= to_segs(decenas);
        hex0 <= to_segs(unidades);
        hex3 <= "0001001"; -- Letra 'H' para indicar que el valor mostrado es Humedad
    end process bcd_a_7segmentos;

end architecture;