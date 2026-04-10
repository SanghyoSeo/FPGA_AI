`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/12/16 23:07:22
// Design Name: 
// Module Name: window_gen_3x3
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
`default_nettype none

module window_gen_3x3 #(
    parameter IMG_WIDTH = 28,
    parameter IMG_HEIGHT = 28
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    
    input wire [7:0] line0_in,
    input wire [7:0] line1_in,
    input wire [7:0] line2_in,
    
    output reg [7:0] w00, w01, w02,
    output reg [7:0] w10, w11, w12,
    output reg [7:0] w20, w21, w22,
    
    output reg calc_valid
    );
    
    // 좌표 카운터 
    reg [9:0] col_cnt;
    reg [9:0] row_cnt;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 0;
            row_cnt <= 0;
        end else if (valid_in) begin
        
            // column ++
            if (col_cnt == IMG_WIDTH - 1) begin
                col_cnt <= 0;
                
                // row ++
                if (row_cnt == IMG_HEIGHT - 1) begin
                    row_cnt <= 0;
                end else begin
                    row_cnt <= row_cnt + 1;
                end
                
            end else begin
                col_cnt <= col_cnt + 1;
            end
        end
    end
    
    // 윈도우 시프트 레지스터
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w00 <= 0; w01 <= 0; w02 <= 0;
            w10 <= 0; w11 <= 0; w12 <= 0;
            w20 <= 0; w21 <= 0; w22 <= 0;
        end else if (valid_in) begin
            // row 0 (위)
            w00 <= w01;
            w01 <= w02;
            w02 <= line0_in;
            
            // row 1 (중간)
            w10 <= w11;
            w11 <= w12;
            w12 <= line1_in;
            
            // row 2 (아래)
            w20 <= w21;
            w21 <= w22;
            w22 <= line2_in;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            calc_valid <= 0;
        end else if (valid_in) begin
        
            // 왼쪽 가장자리, 위쪽 가장자리 무시
            if (col_cnt >= 2 && row_cnt >= 2) begin
                calc_valid <= 1;
            end else begin
                calc_valid <= 0;
            end
            
        end else begin
            calc_valid <= 0;
        end
    end
    
endmodule

module window_gen_3x3_tb();

    reg clk = 0;
    reg rst_n = 0;
    reg valid_in = 0;
    
    reg [7:0] line0_in;
    reg [7:0] line1_in;
    reg [7:0] line2_in;
    
    wire [7:0] w00, w01, w02;
    wire [7:0] w10, w11, w12;
    wire [7:0] w20, w21, w22;
    wire calc_valid;

    // 파라미터 (5x5)
    localparam TB_WIDTH  = 5;
    localparam TB_HEIGHT = 5;

    // DUT 연결
    window_gen_3x3 #(
        .IMG_WIDTH(TB_WIDTH),
        .IMG_HEIGHT(TB_HEIGHT)
    ) u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .line0_in(line0_in),
        .line1_in(line1_in),
        .line2_in(line2_in),
        .w00(w00), .w01(w01), .w02(w02),
        .w10(w10), .w11(w11), .w12(w12),
        .w20(w20), .w21(w21), .w22(w22),
        .calc_valid(calc_valid)
    );

    always #5 clk = ~clk; // 100MHz

    integer r, c; 

    initial begin
        rst_n = 0;
        valid_in = 0;
        line0_in = 0; line1_in = 0; line2_in = 0;
        
        #100;
        rst_n = 1;
        #100;
        
        $display("=== Simulation Start ===");
        
        // 시작 전 타이밍 맞추기 (하강 엣지 대기)
        @(negedge clk);

        for (r = 0; r < TB_HEIGHT; r = r + 1) begin
            
            // 한 줄 데이터 전송 (0 ~ 4)
            for (c = 0; c < TB_WIDTH; c = c + 1) begin
                
                valid_in = 1;
                
                // 데이터 값 계산 (1, 2, 3 ... 25)
                // r=1(2번째 줄), c=0 이면 -> 1*5 + 0 + 1 = 6 (정확히 6이 됨)
                
                // (1) 현재 줄
                line2_in = (r * TB_WIDTH) + c + 1;
                
                // (2) 1줄 전 (데이터 재사용)
                if (r >= 1) line1_in = ((r-1) * TB_WIDTH) + c + 1;
                else        line1_in = 0; 
                
                // (3) 2줄 전 (데이터 재사용)
                if (r >= 2) line0_in = ((r-2) * TB_WIDTH) + c + 1;
                else        line0_in = 0;
                
                // 한 픽셀 유지
                @(negedge clk);
            end
            
            // 한 줄 끝남: Blanking
            valid_in = 0;
            line0_in = 0; line1_in = 0; line2_in = 0;
            
            // [핵심 수정] #20 대신 클럭을 세서 기다립니다. (동기화 보장)
            repeat(2) @(negedge clk); 
        end
        
        $display("=== Finished ===");
        #100;
        $finish;
    end
    
    always @(posedge clk) begin
        if (calc_valid) begin
            $display("[Valid Output] Center Pixel: %d (w11)", w11);
            // $display("Window:\n %d %d %d\n %d %d %d\n %d %d %d", w00, w01, w02, w10, w11, w12, w20, w21, w22);
        end
    end
    
endmodule