`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/14 13:49:16
// Design Name: 
// Module Name: VGA2HDMI
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module VGA2HDMI(
    input pixclk,           // 25MHz
    input clk_TMDS,         // [수정됨] 250MHz (외부 입력으로 변경)
    input VSYNC, HSYNC, ACTIVE,
    input [7:0] red, green, blue,
    output [2:0] TMDSp, TMDSn,
    output TMDSp_clock, TMDSn_clock
);

// C. HDMI Controller
// 4. TMDS ENCODING
wire [9:0] TMDS_red, TMDS_green, TMDS_blue;
TMDS_encoder encode_R(.clk(pixclk), .VD(red  ), .CD(2'b00), 
            .VDE(ACTIVE), .TMDS(TMDS_red));
TMDS_encoder encode_G(.clk(pixclk), .VD(green), .CD(2'b00),        
            .VDE(ACTIVE), .TMDS(TMDS_green));
TMDS_encoder encode_B(.clk(pixclk), .VD(blue ), .CD({VSYNC,HSYNC}), 
            .VDE(ACTIVE), .TMDS(TMDS_blue));

// 5. TMDS CLOCK
// [삭제됨] 내부에서 clk_wiz_1을 사용하지 않고 입력받은 clk_TMDS를 사용합니다.
// wire clk_TMDS;  
// clk_wiz_1 c0(.clk_in1(pixclk),.clk_out1(clk_TMDS));

// 6. TMDS SHIFTER
reg [3:0] TMDS_mod10=0;  // modulus 10 counter
reg [9:0] TMDS_shift_red=0, TMDS_shift_green=0, TMDS_shift_blue=0;
reg TMDS_shift_load=0;

always @(posedge clk_TMDS) 
    TMDS_shift_load <= (TMDS_mod10==4'd9);

always @(posedge clk_TMDS)
begin
    TMDS_shift_red   <= TMDS_shift_load ? TMDS_red   : 
                         TMDS_shift_red  [9:1];
    TMDS_shift_green <= TMDS_shift_load ? TMDS_green : 
                         TMDS_shift_green[9:1];
    TMDS_shift_blue  <= TMDS_shift_load ? TMDS_blue  : 
                         TMDS_shift_blue [9:1]; 
    TMDS_mod10 <= (TMDS_mod10==4'd9) ? 4'd0 : 
                         TMDS_mod10+4'd1;
end

OBUFDS OBUFDS_red  (.I(TMDS_shift_red  [0]), .O(TMDSp[2]), .OB(TMDSn[2]));
OBUFDS OBUFDS_green(.I(TMDS_shift_green[0]), .O(TMDSp[1]), .OB(TMDSn[1]));
OBUFDS OBUFDS_blue (.I(TMDS_shift_blue [0]), .O(TMDSp[0]), .OB(TMDSn[0]));
OBUFDS OBUFDS_clock(.I(pixclk), .O(TMDSp_clock), .OB(TMDSn_clock));

endmodule


// TMDS ENCODER (지난번 수정 사항 포함됨)
module TMDS_encoder(
    input clk,
    input [7:0] VD,  // video data (red, green or blue)
    input [1:0] CD,  // control data
    input VDE,       // video data enable
    output reg [9:0] TMDS = 0
);

    wire [3:0] Nb1s = VD[0] + VD[1] + VD[2] + VD[3] + VD[4] + VD[5] + VD[6] + VD[7];
    wire XNOR = (Nb1s > 4'd4) || (Nb1s == 4'd4 && VD[0] == 1'b0);
    
    // [수정됨] q_m 로직을 루프 없이 명시적으로 전개 (Synthesis Error 방지)
    wire [8:0] q_m;
    assign q_m[0] = VD[0];
    assign q_m[1] = (XNOR) ? (q_m[0] ~^ VD[1]) : (q_m[0] ^ VD[1]);
    assign q_m[2] = (XNOR) ? (q_m[1] ~^ VD[2]) : (q_m[1] ^ VD[2]);
    assign q_m[3] = (XNOR) ? (q_m[2] ~^ VD[3]) : (q_m[2] ^ VD[3]);
    assign q_m[4] = (XNOR) ? (q_m[3] ~^ VD[4]) : (q_m[3] ^ VD[4]);
    assign q_m[5] = (XNOR) ? (q_m[4] ~^ VD[5]) : (q_m[4] ^ VD[5]);
    assign q_m[6] = (XNOR) ? (q_m[5] ~^ VD[6]) : (q_m[5] ^ VD[6]);
    assign q_m[7] = (XNOR) ? (q_m[6] ~^ VD[7]) : (q_m[6] ^ VD[7]);
    assign q_m[8] = (XNOR) ? 1'b0 : 1'b1;

    reg [3:0] balance_acc = 0;
    wire [3:0] balance = q_m[0] + q_m[1] + q_m[2] + q_m[3] + 
                         q_m[4] + q_m[5] + q_m[6] + q_m[7] - 4'd4;
    wire balance_sign_eq = (balance[3] == balance_acc[3]);
    wire invert_q_m = (balance == 0 || balance_acc == 0) ? ~q_m[8] : balance_sign_eq;
    wire [3:0] balance_acc_inc = balance - ({q_m[8] ^ ~balance_sign_eq} & ~(balance == 0 || balance_acc == 0));
    wire [3:0] balance_acc_new = invert_q_m ? balance_acc - balance_acc_inc : balance_acc + balance_acc_inc;
    
    wire [9:0] TMDS_data = {invert_q_m, q_m[8], q_m[7:0] ^ {8{invert_q_m}}};
    wire [9:0] TMDS_code = CD[1] ? (CD[0] ? 10'b1010101011 : 10'b0101010100) : 
                                   (CD[0] ? 10'b0010101011 : 10'b1101010100);

    always @(posedge clk) 
        TMDS <= VDE ? TMDS_data : TMDS_code;
    
    always @(posedge clk) 
        balance_acc <= VDE ? balance_acc_new : 4'h0;

endmodule