library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity red_light_green_light is
    Port (
        clk     : in  STD_LOGIC;
        reset   : in  STD_LOGIC;
        btn     : in  STD_LOGIC;
        sw      : in  STD_LOGIC_VECTOR(3 downto 0);
        led     : out STD_LOGIC_VECTOR(3 downto 0);
        seg     : out STD_LOGIC_VECTOR(6 downto 0);
        an      : out STD_LOGIC_VECTOR(7 downto 0)   
    );
end red_light_green_light;

architecture Behavioral of red_light_green_light is

    signal count1 : integer range 0 to 10 := 0;       -- was 100000000
    signal count2 : integer range 0 to 5  := 0;       -- was 100000

    signal clk_en_1hz  : STD_LOGIC := '0';
    signal clk_en_fast : STD_LOGIC := '0';
    signal btn_sync0   : STD_LOGIC := '0';
    signal btn_sync1   : STD_LOGIC := '0';   
    signal btn_prev    : STD_LOGIC := '0';   
    signal db_count    : integer range 0 to 3 := 0;   -- was 999999
    signal btn_stable  : STD_LOGIC := '0';   
    signal btn_pressed : STD_LOGIC := '0';   

    constant DB_CYCLES : integer := 3;                 -- was 999999
    
    -- FSM
    type state_type is (IDLE, GREEN, RED, DONE);
    signal state_reg  : state_type := IDLE;
    signal state_next : state_type := IDLE;
    
    -- Game data
    type arr is array (0 to 3) of integer range 0 to 15;
    signal distance : arr := (others => 0);
    signal alive    : STD_LOGIC_VECTOR(3 downto 0) := "1111";

    signal iteration     : integer range 0 to 15 := 0;
    signal time_counter  : integer range 0 to 63 := 0;
    signal max_time      : integer range 0 to 63 := 6;
    signal red_processed : STD_LOGIC := '0';

    signal lfsr        : STD_LOGIC_VECTOR(7 downto 0) := "10101100"; 
    signal nom_time    : integer range 0 to 63 := 6;   
    signal blink       : STD_LOGIC := '0';
    signal blink_count : integer range 0 to 4 := 0;   -- was 199

    -- 8-digit multiplexed display
    signal digit       : integer range 0 to 7  := 0;
    signal display_val : integer range 0 to 15 := 0;
    signal time_remain : integer range 0 to 63 := 0;

begin

    -- Clock-enable generator
    process(clk)
    begin
        if rising_edge(clk) then
            clk_en_1hz  <= '0';
            clk_en_fast <= '0';
            if count1 = 9 then                         -- was 99999999
                count1     <= 0;
                clk_en_1hz <= '1';
            else
                count1 <= count1 + 1;
            end if;
            if count2 = 4 then                         -- was 99999
                count2      <= 0;
                clk_en_fast <= '1';
            else
                count2 <= count2 + 1;
            end if;
        end if;
    end process;

    -- Free-running 8-bit Galois LFSR (taps: bits 8,6,5,4)
    process(clk, reset)
    begin
        if reset = '1' then
            lfsr <= "10101100";   
        elsif rising_edge(clk) then
            lfsr(7) <= lfsr(0);
            lfsr(6) <= lfsr(7) xor lfsr(0);
            lfsr(5) <= lfsr(6) xor lfsr(0);
            lfsr(4) <= lfsr(5) xor lfsr(0);
            lfsr(3) <= lfsr(4);
            lfsr(2) <= lfsr(3);
            lfsr(1) <= lfsr(2);
            lfsr(0) <= lfsr(1);
        end if;
    end process;

    -- Button debouncer
    process(clk, reset)
    begin
        if reset = '1' then
            btn_sync0   <= '0';
            btn_sync1   <= '0';
            btn_prev    <= '0';
            db_count    <= 0;
            btn_stable  <= '0';
            btn_pressed <= '0';

        elsif rising_edge(clk) then
            btn_sync0 <= btn;
            btn_sync1 <= btn_sync0;
            btn_pressed <= '0';

            if btn_sync1 /= btn_prev then
                db_count <= 0;
                btn_prev <= btn_sync1;
            elsif db_count < DB_CYCLES then
                db_count <= db_count + 1;
            else
                if btn_sync1 = '1' and btn_stable = '0' then
                    btn_pressed <= '1';   
                end if;
                btn_stable <= btn_sync1;
            end if;
        end if;
    end process;

    -- FSM state register
    process(clk, reset)
    begin
        if reset = '1' then
            state_reg <= IDLE;
        elsif rising_edge(clk) then
            state_reg <= state_next;
        end if;
    end process;

    -- FSM next-state logic
    process(state_reg, btn_pressed, time_counter, max_time, iteration)
    begin
        case state_reg is

            when IDLE =>
                if btn_pressed = '1' then
                    state_next <= GREEN;
                else
                    state_next <= IDLE;
                end if;

            when GREEN =>
                if time_counter >= max_time then
                    state_next <= RED;
                else
                    state_next <= GREEN;
                end if;

            when RED =>
                if iteration >= 10 then
                    state_next <= DONE;
                elsif btn_pressed = '1' then
                    state_next <= GREEN;
                else
                    state_next <= RED;
                end if;

            when DONE =>
                state_next <= DONE;

        end case;
    end process;

    -- Game logic (1 Hz tick)
    process(clk, reset)
        variable new_nom : integer range 0 to 63;
        variable offset  : integer range 0 to 15;
        variable actual  : integer range 0 to 78;
    begin
        if reset = '1' then
            distance      <= (others => 0);
            alive         <= "1111";
            iteration     <= 0;
            nom_time      <= 6;
            max_time      <= 6;
            time_counter  <= 0;
            red_processed <= '0';

        elsif rising_edge(clk) then
            if clk_en_1hz = '1' then

                if state_reg = GREEN then
                    red_processed <= '0';

                    if time_counter < max_time then
                        time_counter <= time_counter + 1;
                    end if;

                    for i in 0 to 3 loop
                        if sw(i) = '1' and alive(i) = '1' then
                            distance(i) <= distance(i) + 1;
                        end if;
                    end loop;

                elsif state_reg = RED then
                    time_counter <= 0;

                    if red_processed = '0' then
                        red_processed <= '1';
                        iteration     <= iteration + 1;

                        new_nom  := (nom_time * 3) / 4;
                        nom_time <= new_nom;
                        offset := new_nom / 4;
                        case lfsr(1 downto 0) is
                            when "01" =>
                                actual := new_nom + offset;
                            when "10" =>
                                if new_nom > offset then
                                    actual := new_nom - offset;
                                else
                                    actual := 1;   
                                end if;
                            when others =>
                                actual := new_nom;
                        end case;

                        if actual < 1 then
                            max_time <= 1;
                        elsif actual > 63 then
                            max_time <= 63;
                        else
                            max_time <= actual;
                        end if;

                        for i in 0 to 3 loop
                            if sw(i) = '1' then
                                alive(i) <= '0';
                            end if;
                        end loop;
                    end if;

                elsif state_reg = IDLE then
                    time_counter <= 0;

                end if;
            end if;
        end if;
    end process;

    -- Blink (~5 Hz)
    process(clk)
    begin
        if rising_edge(clk) then
            if clk_en_fast = '1' then
                if blink_count = 3 then                -- was 199
                    blink_count <= 0;
                    blink       <= not blink;
                else
                    blink_count <= blink_count + 1;
                end if;
            end if;
        end if;
    end process;

    -- LED output
    process(distance, alive, blink)
    begin
        for i in 0 to 3 loop
            if distance(i) >= 10 then
                led(i) <= blink;    
            elsif alive(i) = '1' then
                led(i) <= '1';      
            else
                led(i) <= '0';      
            end if;
        end loop;
    end process;

    -- 8-digit multiplexer
    process(clk)
    begin
        if rising_edge(clk) then
            if clk_en_fast = '1' then
                digit <= (digit + 1) mod 8;
            end if;
        end if;
    end process;

    -- Time remaining (combinational helper)
    time_remain <= max_time - time_counter when max_time >= time_counter else 0;

    process(digit, distance, state_reg, time_remain)
    begin
        case digit is
            when 0 =>
                display_val <= 15;

            when 1 =>
                display_val <= time_remain mod 10;

            when 2 =>
                display_val <= time_remain / 10;

            when 3 =>
                display_val <= 15;

            when 4 =>
                if state_reg = GREEN then
                    display_val <= distance(0);
                else
                    display_val <= 15;
                end if;

            when 5 =>
                if state_reg = GREEN then
                    display_val <= distance(1);
                else
                    display_val <= 15;
                end if;

            when 6 =>
                if state_reg = GREEN then
                    display_val <= distance(2);
                else
                    display_val <= 15;
                end if;

            when others =>
                if state_reg = GREEN then
                    display_val <= distance(3);
                else
                    display_val <= 15;
                end if;
        end case;
    end process;

    -- Anode select
    process(digit)
    begin
        case digit is
            when 0      => an <= "11111110";
            when 1      => an <= "11111101";
            when 2      => an <= "11111011";
            when 3      => an <= "11110111";
            when 4      => an <= "11101111";
            when 5      => an <= "11011111";
            when 6      => an <= "10111111";
            when others => an <= "01111111";
        end case;
    end process;

    -- 7-segment decoder
    process(display_val)
    begin
        case display_val is
            when 0      => seg <= "1000000";
            when 1      => seg <= "1111001";
            when 2      => seg <= "0100100";
            when 3      => seg <= "0110000";
            when 4      => seg <= "0011001";
            when 5      => seg <= "0010010";
            when 6      => seg <= "0000010";
            when 7      => seg <= "1111000";
            when 8      => seg <= "0000000";
            when 9      => seg <= "0010000";
            when others => seg <= "1111111";
        end case;
    end process;

end Behavioral;
