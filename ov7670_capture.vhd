library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ov7670_capture is
    Port ( pclk        : in    STD_LOGIC;
           rez_160x120 : IN std_logic;
           rez_320x240 : IN std_logic;
           sw          : in    STD_LOGIC_VECTOR(1 downto 0); 
           btn_up      : in STD_LOGIC;
           btn_down    : in STD_LOGIC;
           vsync       : in    STD_LOGIC;
           href        : in    STD_LOGIC;
           d           : in    STD_LOGIC_VECTOR (7 downto 0);
           addr        : out   STD_LOGIC_VECTOR (18 downto 0);
           dout        : out   STD_LOGIC_VECTOR (11 downto 0);
           we          : out   STD_LOGIC;
           x_center    : out STD_LOGIC_VECTOR(9 downto 0);
           y_center    : out STD_LOGIC_VECTOR(9 downto 0)
           );
end ov7670_capture;

architecture Behavioral of ov7670_capture is
   signal d_latch        : std_logic_vector(15 downto 0) := (others => '0');
   signal address        : STD_LOGIC_VECTOR(18 downto 0) := (others => '0');
   signal href_last      : std_logic_vector(6 downto 0)  := (others => '0');
   signal we_reg         : std_logic := '0';
   signal latched_vsync : STD_LOGIC := '0';
   signal latched_href  : STD_LOGIC := '0';
   signal latched_d     : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');

   signal sum_x : unsigned(31 downto 0) := (others => '0');
   signal sum_y : unsigned(31 downto 0) := (others => '0');
   signal pixel_cnt : unsigned(19 downto 0) := (others => '0');
   signal x_curr : unsigned(9 downto 0) := (others => '0');
   signal y_curr : unsigned(9 downto 0) := (others => '0');
   signal x_result : std_logic_vector(9 downto 0) := (others => '0');
   signal y_result : std_logic_vector(9 downto 0) := (others => '0');

   -- [설정] 임계값 160
   signal threshold_val : unsigned(7 downto 0) := to_unsigned(160, 8); 

begin
   addr <= address;
   we <= we_reg;
   x_center <= x_result;
   y_center <= y_result;
   
   capture_process: process(pclk)
      -- [변수 선언]
      variable temp_x : integer;
      variable temp_y : integer;
   begin
      if rising_edge(pclk) then
         if we_reg = '1' then
            address <= std_logic_vector(unsigned(address)+1);
         end if;

         if latched_href = '1' then
            d_latch <= d_latch( 7 downto 0) & latched_d;
         end if;
         we_reg  <= '0';

         if latched_vsync = '1' then 
            address       <= (others => '0');
            href_last     <= (others => '0');
            x_curr <= (others => '0');
            y_curr <= (others => '0');

            if btn_up = '1' then
                if threshold_val < 250 then threshold_val <= threshold_val + 5; end if;
            elsif btn_down = '1' then
                if threshold_val > 10 then threshold_val <= threshold_val - 5; end if;
            end if;

            -- [좌표 계산 및 Safety Wall]
            if pixel_cnt > 50 then 
               -- 1. 무게중심 계산
               temp_x := to_integer(sum_x / pixel_cnt);
               temp_y := to_integer(sum_y / pixel_cnt);

               -- 2. X축 벽 (56 ~ 583)
               if temp_x < 56 then temp_x := 56; end if;
               if temp_x > 583 then temp_x := 583; end if;

               -- 3. Y축 벽 (56 ~ 423) -> 여기가 핵심!
               -- 중심이 423이면 박스 끝은 423+56=479 (세이프!)
               -- 중심이 424면 박스 끝은 424+56=480 (위험!)
               if temp_y < 56 then temp_y := 56; end if;
               if temp_y > 423 then temp_y := 423; end if;

               -- 4. 결과 출력
               x_result <= std_logic_vector(to_unsigned(temp_x, 10));
               y_result <= std_logic_vector(to_unsigned(temp_y, 10));
            end if;

            sum_x <= (others => '0'); sum_y <= (others => '0'); pixel_cnt <= (others => '0');
         else
            if href_last(0) = '1' then 
               we_reg <= '1';
               href_last <= (others => '0');
               
               x_curr <= x_curr + 1;
               if x_curr = 639 then 
                  x_curr <= (others => '0'); y_curr <= y_curr + 1;
               end if;

               -- [님 의견 반영] 478라인까지 인식 허용 (화면 끝 노이즈 1~2줄만 무시)
               if (unsigned(d) > threshold_val) and (y_curr < 478) then
                  dout <= x"FFF"; 
                  sum_x <= sum_x + x_curr;
                  sum_y <= sum_y + y_curr;
                  pixel_cnt <= pixel_cnt + 1;
               else
                  dout <= x"000"; 
               end if;

            else
               we_reg <= '0';
               href_last <= href_last(href_last'high-1 downto 0) & latched_href;
            end if;
         end if;
      end if;
      if falling_edge(pclk) then
         latched_d <= d; latched_href <= href; latched_vsync <= vsync;
      end if;      
   end process;
end Behavioral;