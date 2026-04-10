`timescale 1ns / 1ps
// [핵심 수정] system_top의 'none' 설정 영향을 끊고, 여기서부터는 wire를 기본값으로 사용합니다.
`default_nettype wire 

//////////////////////////////////////////////////////////////////////////////////
// Module Name: ov7670_registers_2
//////////////////////////////////////////////////////////////////////////////////

module ov7670_registers_2(
    input wire clk,      // [수정] input -> input wire
    input wire resend,   // [수정] input -> input wire
    input wire advance,  // [수정] input -> input wire
    output wire [15:0] command, // [수정] assign으로 연결되므로 output wire여야 함
    output wire finished // [수정] output -> output wire
);

    //내부 신호
    reg [15:0] sreg;  //레지스터 주소를 나타내는 변수
    reg finished_temp;  //구성이 완료되었음을 나타내는 신호
    reg [7:0] address = {8{1'b0}};  //주소의 크기는 넉넉히 8비트
    
    //출력에 값 할당
    assign command = sreg;  // OV7670에 대한 레지스터 값 및 데이터를 Conroller에서 사용하는 command 변수에 옮김
    assign finished = finished_temp;  //구성이 완료되었음을 나타내는 신호를 Conroller에서 사용하는 finished 변수에 옮김
    
    //레지스터와 값이 FFFF 인 경우
    //구성이 완료되었음을 나타내는 신호가 표시됩니다.(finished_temp)
    always @ (sreg) begin
        if(sreg == 16'hFFFF) begin
            finished_temp <= 1;
        end
        else begin
            finished_temp <= 0;  //구성이 완료되지 않았다.
        end
    end
    
    //lookuptable에서 데이터 얻기(레지스터에서)
    always @ (posedge clk) begin
        if(resend == 1) begin           //새로고침 신호
            address <= {8{1'b0}};       //초기화
        end
        else if(advance == 1) begin     //아니라면 다음 데이터 얻기
            address <= address+1;       //주소값에 1씩 더해주면서 원하는 레지스터 값을 찾음
        end
            
        case (address)  //주소의 값에 따라 원하는 레지스터에 들어가서 값을 가지고 나옴
                0:  sreg <= 16'h12_80; //reset
                1:  sreg <= 16'hFF_F0; //delay
                2:  sreg <= 16'h12_00; // COM7,      set RGB color output
                3:  sreg <= 16'h11_80; // CLKRC      internal PLL matches input clock
                4:  sreg <= 16'h0C_00; // COM3,      default settings
                5:  sreg <= 16'h3E_00; // COM14,     no scaling, normal pclock
                6:  sreg <= 16'h04_00; // COM1,      disable CCIR656
                7:  sreg <= 16'h40_d0; //COM15,      RGB565, full output range
                8:  sreg <= 16'h3a_04; //TSLB        set correct output data sequence (magic)
                9:  sreg <= 16'h14_18; //COM9        MAX AGC value x4
                10: sreg <= 16'h4F_B3; //MTX1        all of these are magical matrix coefficients
                11: sreg <= 16'h50_B3; //MTX2
                12: sreg <= 16'h51_00; //MTX3
                13: sreg <= 16'h52_3d; //MTX4
                14: sreg <= 16'h53_A7; //MTX5
                15: sreg <= 16'h54_E4; //MTX6
                16: sreg <= 16'h58_9E; //MTXS
                17: sreg <= 16'h3D_C0; //COM13       sets gamma enable
                18: sreg <= 16'h17_14; //HSTART      start high 8 bits
                19: sreg <= 16'h18_02; //HSTOP       stop high 8 bits
                20: sreg <= 16'h32_80; //HREF        edge offset
                21: sreg <= 16'h19_03; //VSTART      start high 8 bits
                22: sreg <= 16'h1A_7B; //VSTOP       stop high 8 bits
                23: sreg <= 16'h03_0A; //VREF        vsync edge offset
                24: sreg <= 16'h0F_41; //COM6        reset timings
                25: sreg <= 16'h1E_00; //MVFP        disable mirror / flip
                26: sreg <= 16'h33_0B; //CHLF        magic value
                27: sreg <= 16'h3C_78; //COM12       no HREF when VSYNC low
                //28: sreg <= 16'h69_00; //GFIX        fix gain control
                28: sreg <= 16'h69_0a; //GFIX  
                29: sreg <= 16'h74_00; //REG74       Digital gain control
                30: sreg <= 16'hB0_84; //RSVD        magic value
                31: sreg <= 16'hB1_0c; //ABLC1
                32: sreg <= 16'hB2_0e; //RSVD        more magic internet values
                33: sreg <= 16'hB3_80; //THL_ST
                //begin mystery scaling numbers
                34: sreg <= 16'h70_3a;
                35: sreg <= 16'h71_35;
                36: sreg <= 16'h72_11;
                37: sreg <= 16'h73_f0;
                38: sreg <= 16'ha2_02;
                //gamma curve values
                39: sreg <= 16'h7a_20;
                40: sreg <= 16'h7b_10;
                41: sreg <= 16'h7c_1e;
                42: sreg <= 16'h7d_35;
                43: sreg <= 16'h7e_5a;
                44: sreg <= 16'h7f_69;
                45: sreg <= 16'h80_76;
                46: sreg <= 16'h81_80;
                47: sreg <= 16'h82_88;
                48: sreg <= 16'h83_8f;
                49: sreg <= 16'h84_96;
                50: sreg <= 16'h85_a3;
                51: sreg <= 16'h86_af;
                52: sreg <= 16'h87_c4;
                53: sreg <= 16'h88_d7;
                54: sreg <= 16'h89_e8;
                //AGC and AEC
                55: sreg <= 16'h13_e0; //COM8, disable AGC / AEC
                56: sreg <= 16'h00_00; //set gain reg to 0 for AGC
                57: sreg <= 16'h10_00; //set ARCJ reg to 0
                58: sreg <= 16'h0d_40; //magic reserved bit for COM4
                59: sreg <= 16'h14_18; //COM9, 4x gain + magic bit
                60: sreg <= 16'ha5_05; // BD50MAX
                61: sreg <= 16'hab_07; //DB60MAX
                62: sreg <= 16'h24_95; //AGC upper limit
                63: sreg <= 16'h25_33; //AGC lower limit
                64: sreg <= 16'h26_e3; //AGC/AEC fast mode op region
                65: sreg <= 16'h9f_78; //HAECC1
                66: sreg <= 16'ha0_68; //HAECC2
                67: sreg <= 16'ha1_03; //magic
                68: sreg <= 16'ha6_d8; //HAECC3
                69: sreg <= 16'ha7_d8; //HAECC4
                70: sreg <= 16'ha8_f0; //HAECC5
                71: sreg <= 16'ha9_90; //HAECC6
                72: sreg <= 16'haa_94; //HAECC7
                73: sreg <= 16'h13_e5; //COM8, enable AGC / AEC
                default : sreg <= 16'hFFFF;  //sreg값이 ffff이면 구성이 완료 되었다.
        endcase
    end
endmodule

// Testbench는 합성 시 무시되지만, 에러 방지를 위해 남겨둡니다.
module ov7670_registers_setting_tb;
    reg clk=0;
    reg resend;
    reg advance=0;
    wire [15:0] command;
    wire finished;
    
    ov7670_registers_2 uut(clk, resend, advance, command, finished);
    
    always #10 clk=~clk; 
    initial begin
        #100 resend=1;
        #100 resend=0;
    end
    
    always #300 advance = ~advance;
endmodule