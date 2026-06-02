library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sistema_techo_top is
    port(
        clk         : in  std_logic;
        rst         : in  std_logic; 
        
        fc37_lluvia : in  std_logic;
        ldr_sol     : in  std_logic;

        -- Salidas al Puente H
        h_in1       : out std_logic;
        h_in2       : out std_logic;
        h_en_pwm    : out std_logic;

        -- Salidas a los Displays
        hex0        : out std_logic_vector(6 downto 0);
        hex1        : out std_logic_vector(6 downto 0);
        hex2        : out std_logic_vector(6 downto 0);
        hex3        : out std_logic_vector(6 downto 0)
    );
end entity;

architecture estructural of sistema_techo_top is

    -- =================================================================
    -- DECLARACIÓN DEL COMPONENTE ADC (Soluciona el error de librería)
    -- =================================================================
    component adc_interno is
        port (
            CLOCK : in  std_logic;
            RESET : in  std_logic;
            CH0   : out std_logic_vector(11 downto 0);
            CH1   : out std_logic_vector(11 downto 0);
            CH2   : out std_logic_vector(11 downto 0);
            CH3   : out std_logic_vector(11 downto 0);
            CH4   : out std_logic_vector(11 downto 0);
            CH5   : out std_logic_vector(11 downto 0);
            CH6   : out std_logic_vector(11 downto 0);
            CH7   : out std_logic_vector(11 downto 0)
        );
    end component;

    -- Señales internas (cables virtuales)
    signal adc_ch1_slv        : std_logic_vector(11 downto 0);
    signal adc_valor_crudo    : unsigned(11 downto 0); 
    signal cable_suelo_seco   : std_logic;
    signal cable_suelo_humedo : std_logic;
    signal cable_humedad_pct  : natural range 0 to 100;

begin

-- =================================================================
    -- 1. Instancia del ADC (Usando el componente declarado)
    -- =================================================================
    u_adc : adc_interno
        port map (
            CLOCK => clk,
            RESET => rst,
            CH0   => adc_ch1_slv,  -- CH0 corresponde al pin físico Arduino A0
            CH1   => open,
            CH2   => open,
            CH3   => open,
            CH4   => open,
            CH5   => open,
            CH6   => open,
            CH7   => open
        );

    -- Conversión de std_logic_vector a unsigned
    adc_valor_crudo <= unsigned(adc_ch1_slv);

    -- =================================================================
    -- 2. Instancia de tu archivo de procesamiento capacitivo
    -- =================================================================
    u_higrometro : entity work.sen_hs_cap_de10
        generic map (
            ADC_WIDTH => 12,
            DRY_IS_HIGH => true,
            TH_SECO_ON => 3000,
            TH_SECO_OFF => 2600,
            TH_HUMEDO_ON => 1200,
            TH_HUMEDO_OFF => 1600
        )
        port map (
            clk          => clk,
            rst          => rst,
            adc_value    => adc_valor_crudo,
            suelo_seco   => cable_suelo_seco,
            suelo_humedo => cable_suelo_humedo,
            nivel        => open 
        );

    -- =================================================================
    -- Lógica adaptativa: Convertir estados a un porcentaje virtual
    -- =================================================================
	 -- =================================================================
    -- Lógica Matemática: Mapeo lineal del ADC a 0-100%
    -- =================================================================
    process(adc_valor_crudo)
        variable adc_int : integer;
        variable pct_calc : integer;
    begin
        -- 1. Convertimos el valor crudo a un entero normal
        adc_int := to_integer(adc_valor_crudo);
        
        -- 2. Aplicamos la regla de 3 invertida (100% = 0, 0% = 4095)
        pct_calc := 100 - ((adc_int * 100) / 4095);
        
        -- 3. Protecciones de seguridad para no salir del rango 0-100
        if pct_calc > 100 then
            cable_humedad_pct <= 100;
        elsif pct_calc < 0 then
            cable_humedad_pct <= 0;
        else
            cable_humedad_pct <= pct_calc;
        end if;
    end process;

    -- =================================================================
    -- 3. Instancia de la Máquina de Estados (El Cerebro Central)
    -- =================================================================
    u_controlador_techo : entity work.techo_retratil_fsm
        generic map (
            CLK_HZ         => 50000000,
            MOTOR_TIME_SEC => 5
        )
        port map (
            clk         => clk,
            rst         => rst,
            fc37_lluvia => fc37_lluvia,
            ldr_sol     => ldr_sol,
            humedad_pct => cable_humedad_pct, 
            
            h_in1       => h_in1,
            h_in2       => h_in2,
            h_en_pwm    => h_en_pwm,
            
            hex0        => hex0,
            hex1        => hex1,
            hex2        => hex2,
            hex3        => hex3
        );

end architecture;