-- =============================================================
-- Testbench : tb_winner
-- Goal      : Player 3 wins - players 0,1,2 eliminated over
--             3 rounds by having sw high during RED.
--             Player 3 moves 1 step each GREEN then stops.
-- Sim speed : 1 "second" = 100 clock cycles (10 ns each = 1 us)
--             Matches fast constants in red_light_green_light.vhd
-- =============================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_winner is
end tb_winner;

architecture sim of tb_winner is

    component red_light_green_light
        Port (
            clk   : in  STD_LOGIC;
            reset : in  STD_LOGIC;
            btn   : in  STD_LOGIC;
            sw    : in  STD_LOGIC_VECTOR(3 downto 0);
            led   : out STD_LOGIC_VECTOR(3 downto 0);
            seg   : out STD_LOGIC_VECTOR(6 downto 0);
            an    : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    constant CLK_PERIOD  : time    := 10 ns;
    constant CYCLES_1HZ  : integer := 100;  -- matches CNT_1HZ in DUT
    constant CYCLES_FAST : integer := 50;   -- matches CNT_FAST in DUT
    constant DB_CYCLES   : integer := 50;   -- matches DB_CYCLES in DUT

    signal clk        : STD_LOGIC := '0';
    signal reset      : STD_LOGIC := '0';
    signal btn        : STD_LOGIC := '0';
    signal sw         : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal led        : STD_LOGIC_VECTOR(3 downto 0);
    signal seg        : STD_LOGIC_VECTOR(6 downto 0);
    signal an         : STD_LOGIC_VECTOR(7 downto 0);
    signal pass_count : integer := 0;
    signal fail_count : integer := 0;

begin

    uut : red_light_green_light
        port map (
            clk   => clk,
            reset => reset,
            btn   => btn,
            sw    => sw,
            led   => led,
            seg   => seg,
            an    => an
        );

    clk_proc : process
    begin
        clk <= '0'; wait for CLK_PERIOD / 2;
        clk <= '1'; wait for CLK_PERIOD / 2;
    end process;

    stim : process

        procedure advance(n : integer) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        procedure push_btn is
        begin
            btn <= '1';
            for i in 1 to (DB_CYCLES + 10) loop
                wait until rising_edge(clk);
            end loop;
            btn <= '0';
            advance(5);
        end procedure;

        procedure check_cond(condition : boolean; msg : string) is
        begin
            if condition then
                report "[PASS] " & msg severity note;
                pass_count <= pass_count + 1;
            else
                report "[FAIL] " & msg severity error;
                fail_count <= fail_count + 1;
            end if;
        end procedure;

    begin

        -- Reset
        report "--- WINNER TB: Reset ---" severity note;
        reset <= '1';
        advance(20);
        reset <= '0';
        advance(5);
        check_cond(led = "1111", "Reset: all 4 players alive");

        -- -------------------------------------------------------
        -- Round 1: Eliminate player 0
        -- -------------------------------------------------------
        report "--- Round 1: Eliminate player 0 ---" severity note;
        push_btn;
        advance(CYCLES_1HZ + 10);

        -- GREEN: player 3 moves 1 step then stops before RED
        sw <= "1000";
        advance(CYCLES_FAST);
        sw <= "0000";
        advance(CYCLES_1HZ * 3);

        -- RED: player 0 switch high -> eliminated
        sw <= "0001";
        advance(CYCLES_1HZ + 10);
        sw <= "0000";

        check_cond(led(0) = '0', "Round 1: Player 0 eliminated");
        check_cond(led(1) = '1', "Round 1: Player 1 alive");
        check_cond(led(2) = '1', "Round 1: Player 2 alive");
        check_cond(led(3) = '1', "Round 1: Player 3 alive (winner candidate)");

        -- -------------------------------------------------------
        -- Round 2: Eliminate player 1
        -- -------------------------------------------------------
        report "--- Round 2: Eliminate player 1 ---" severity note;
        push_btn;
        advance(CYCLES_1HZ + 10);

        sw <= "1000";
        advance(CYCLES_FAST);
        sw <= "0000";
        advance(CYCLES_1HZ * 3);

        sw <= "0010";
        advance(CYCLES_1HZ + 10);
        sw <= "0000";

        check_cond(led(0) = '0', "Round 2: Player 0 stays eliminated");
        check_cond(led(1) = '0', "Round 2: Player 1 eliminated");
        check_cond(led(2) = '1', "Round 2: Player 2 alive");
        check_cond(led(3) = '1', "Round 2: Player 3 alive (winner candidate)");

        -- -------------------------------------------------------
        -- Round 3: Eliminate player 2 -> player 3 wins
        -- -------------------------------------------------------
        report "--- Round 3: Eliminate player 2 - player 3 WINS ---" severity note;
        push_btn;
        advance(CYCLES_1HZ + 10);

        sw <= "1000";
        advance(CYCLES_FAST);
        sw <= "0000";
        advance(CYCLES_1HZ * 3);

        sw <= "0100";
        advance(CYCLES_1HZ + 10);
        sw <= "0000";

        check_cond(led(0) = '0', "Round 3: Player 0 stays eliminated");
        check_cond(led(1) = '0', "Round 3: Player 1 stays eliminated");
        check_cond(led(2) = '0', "Round 3: Player 2 eliminated");
        check_cond(led(3) = '1', "Round 3: Player 3 is LAST SURVIVOR = WINNER");

        report "--- Final winner check ---" severity note;
        check_cond(led = "1000", "WINNER: Only player 3 LED on, all others off");

        report "========================================" severity note;
        report "tb_winner complete." severity note;
        report "PASS: " & integer'image(pass_count) severity note;
        report "FAIL: " & integer'image(fail_count) severity note;
        report "========================================" severity note;
        if fail_count = 0 then
            report "ALL WINNER TESTS PASSED" severity note;
        else
            report "SOME WINNER TESTS FAILED" severity warning;
        end if;

        wait;
    end process stim;

end sim;
