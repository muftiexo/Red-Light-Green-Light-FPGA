library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_losing is
end tb_losing;

architecture sim of tb_losing is

    constant CLK_PERIOD : time := 10 ns;

    signal clk   : STD_LOGIC := '0';
    signal reset : STD_LOGIC := '1';
    signal btn   : STD_LOGIC := '0';
    signal sw    : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal led   : STD_LOGIC_VECTOR(3 downto 0);
    signal seg   : STD_LOGIC_VECTOR(6 downto 0);
    signal an    : STD_LOGIC_VECTOR(7 downto 0);

begin

    clk <= not clk after CLK_PERIOD / 2;

    UUT : entity work.red_light_green_light
        port map (
            clk   => clk,
            reset => reset,
            btn   => btn,
            sw    => sw,
            led   => led,
            seg   => seg,
            an    => an
        );

    stim : process
    begin
        reset <= '1';
        wait for 50 ns;
        reset <= '0';
        wait for 50 ns;

        btn <= '1';
        wait for 70 ns;
        btn <= '0';
        wait for 80 ns;

        sw <= "0001";
        wait for 900 ns;

        assert led(0) = '0'
            report "FAIL: player 0 should be dead after moving during RED"
            severity error;

        report "PASS: player 0 eliminated, losing condition confirmed"
            severity note;

        assert led(3 downto 1) = "111"
            report "FAIL: players 1-3 should still be alive"
            severity error;

        report "PASS: players 1-3 still alive as expected"
            severity note;

        wait;
    end process;

end sim;
