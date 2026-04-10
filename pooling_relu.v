`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/12/28 17:33:36
// Design Name: 
// Module Name: pooling_relu
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

module pooling_relu #(
    parameter DATA_WIDTH = 20,
    parameter IMG_WIDTH  = 638  // Conv 후 크기 (640-2)
)(
    input  wire clk,
    input  wire rst_n,
    input  wire valid_in,
    input  wire signed [DATA_WIDTH-1:0] data_in,
    
    output reg valid_out,
    output reg signed [DATA_WIDTH-1:0] data_out
);

    wire signed [DATA_WIDTH-1:0] relu_val;
    assign relu_val = (data_in < 0) ? 0 : data_in;

    // Line Buffer & Pointer
    reg signed [DATA_WIDTH-1:0] line_buff [0:IMG_WIDTH-1];
    reg [9:0] wr_ptr; 

    // 2x2 Window Registers
    reg signed [DATA_WIDTH-1:0] val_00, val_01; 
    reg signed [DATA_WIDTH-1:0] val_10, val_11; 

    // Counters
    reg [9:0] col_cnt;
    reg [9:0] row_cnt;

    // [중요] 메모리 초기화 (X 방지)
    integer i;
    initial begin
        for(i=0; i<IMG_WIDTH; i=i+1) begin
            line_buff[i] = 0;
        end
    end

    // Max Function
    function signed [DATA_WIDTH-1:0] max4;
        input signed [DATA_WIDTH-1:0] a, b, c, d;
        reg signed [DATA_WIDTH-1:0] m1, m2;
        begin
            m1 = (a > b) ? a : b;
            m2 = (c > d) ? c : d;
            max4 = (m1 > m2) ? m1 : m2;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            col_cnt <= 0;
            row_cnt <= 0;
            valid_out <= 0;
            data_out <= 0;
            val_00<=0; val_01<=0; val_10<=0; val_11<=0;
        end else if (valid_in) begin
            // 1. Line Buffer Access
            val_01 <= line_buff[wr_ptr]; 
            val_00 <= val_01; 

            line_buff[wr_ptr] <= relu_val;

            if (wr_ptr == IMG_WIDTH - 1) wr_ptr <= 0;
            else wr_ptr <= wr_ptr + 1;

            // 2. Current Row Shift
            val_11 <= relu_val;
            val_10 <= val_11; 

            // 3. Output Logic (Stride 2)
            // 홀수 번째 행 & 홀수 번째 열일 때만 출력 (1, 3, 5...)
            if (row_cnt[0] == 1'b1 && col_cnt[0] == 1'b1) begin
                valid_out <= 1;
                data_out <= max4(val_00, val_01, val_10, val_11);
            end else begin
                valid_out <= 0;
            end

            // 4. Counter Update
            if (col_cnt == IMG_WIDTH - 1) begin
                col_cnt <= 0;
                row_cnt <= row_cnt + 1;
            end else begin
                col_cnt <= col_cnt + 1;
            end
        end else begin
            valid_out <= 0;
        end
    end

endmodule
