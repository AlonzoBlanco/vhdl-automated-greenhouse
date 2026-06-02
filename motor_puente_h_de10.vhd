library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity motor_puente_h_de10 is
    generic(
        CLK_HZ : positive := 50000000;
        PWM_HZ : positive := 1000
    );
    port(
        clk : in  std_logic;
        rst : in  std_logic;

        -- cmd:
        -- 00 = motor apagado
        -- 01 = giro adelante
        -- 10 = giro reversa
        -- 11 = freno
        cmd : in std_logic_vector(1 downto 0);

        -- duty_percent:
        -- 0   = apagado
        -- 100 = velocidad máxima
        duty_percent : in unsigned(6 downto 0);

        h_in1 : out std_logic;
        h_in2 : out std_logic;
        h_en  : out std_logic
    );
end entity;

architecture rtl of motor_puente_h_de10 is

    constant PWM_PERIOD : positive := CLK_HZ / PWM_HZ;

    signal pwm_counter : natural range 0 to PWM_PERIOD - 1 := 0;
    signal duty_clamp  : natural range 0 to 100 := 0;
    signal duty_limit  : natural range 0 to PWM_PERIOD := 0;

    signal pwm_on : std_logic := '0';

begin

    duty_clamp <= 100 when to_integer(duty_percent) > 100 else
                  to_integer(duty_percent);

    duty_limit <= (PWM_PERIOD * duty_clamp) / 100;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pwm_counter <= 0;
            else
                if pwm_counter = PWM_PERIOD - 1 then
                    pwm_counter <= 0;
                else
                    pwm_counter <= pwm_counter + 1;
                end if;
            end if;
        end if;
    end process;

    pwm_on <= '1' when pwm_counter < duty_limit else '0';

    process(cmd, pwm_on)
    begin
        h_in1 <= '0';
        h_in2 <= '0';
        h_en  <= '0';

        case cmd is

            when "00" =>
                -- Motor libre/apagado
                h_in1 <= '0';
                h_in2 <= '0';
                h_en  <= '0';

            when "01" =>
                -- Giro adelante
                h_in1 <= '1';
                h_in2 <= '0';
                h_en  <= pwm_on;

            when "10" =>
                -- Giro reversa
                h_in1 <= '0';
                h_in2 <= '1';
                h_en  <= pwm_on;

            when others =>
                -- Freno
                h_in1 <= '1';
                h_in2 <= '1';
                h_en  <= '1';

        end case;
    end process;

end architecture;