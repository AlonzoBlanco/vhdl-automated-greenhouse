library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sen_hs_cap_de10 is
    generic(
        ADC_WIDTH : positive := 12;

        -- En muchos sensores capacitivos, mayor voltaje suele indicar suelo más seco.
        -- Si en tus pruebas ocurre al revés, cambia DRY_IS_HIGH a false.
        DRY_IS_HIGH : boolean := true;

        -- Umbrales iniciales. Debes calibrarlos con mediciones reales.
        TH_SECO_ON    : natural := 3000;
        TH_SECO_OFF   : natural := 2600;

        TH_HUMEDO_ON  : natural := 1200;
        TH_HUMEDO_OFF : natural := 1600
    );
    port(
        clk          : in  std_logic;
        rst          : in  std_logic;

        adc_value    : in  unsigned(ADC_WIDTH - 1 downto 0);

        suelo_seco   : out std_logic;
        suelo_humedo : out std_logic;

        -- 00 = húmedo
        -- 01 = medio
        -- 10 = seco
        nivel        : out std_logic_vector(1 downto 0)
    );
end entity;

architecture rtl of sen_hs_cap_de10 is

    constant ADC_MAX : unsigned(ADC_WIDTH - 1 downto 0) := (others => '1');

    signal adc_norm : unsigned(ADC_WIDTH - 1 downto 0);
    signal seco_r   : std_logic := '0';
    signal humedo_r : std_logic := '0';

begin

    adc_norm <= adc_value when DRY_IS_HIGH else ADC_MAX - adc_value;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                seco_r   <= '0';
                humedo_r <= '0';
            else

                -- Detección de suelo seco con histéresis
                if adc_norm >= to_unsigned(TH_SECO_ON, ADC_WIDTH) then
                    seco_r <= '1';
                elsif adc_norm <= to_unsigned(TH_SECO_OFF, ADC_WIDTH) then
                    seco_r <= '0';
                end if;

                -- Detección de suelo húmedo con histéresis
                if adc_norm <= to_unsigned(TH_HUMEDO_ON, ADC_WIDTH) then
                    humedo_r <= '1';
                elsif adc_norm >= to_unsigned(TH_HUMEDO_OFF, ADC_WIDTH) then
                    humedo_r <= '0';
                end if;

            end if;
        end if;
    end process;

    suelo_seco   <= seco_r;
    suelo_humedo <= humedo_r;

    nivel <= "10" when seco_r = '1' else
             "00" when humedo_r = '1' else
             "01";

end architecture;