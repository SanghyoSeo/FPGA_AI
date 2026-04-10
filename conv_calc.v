`timescale 1ns / 1ps

module conv_calc(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    
    input wire [7:0] w00, w01, w02,
    input wire [7:0] w10, w11, w12,
    input wire [7:0] w20, w21, w22,
    
    input wire signed [7:0] k00, k01, k02,
    input wire signed [7:0] k10, k11, k12,
    input wire signed [7:0] k20, k21, k22,
    
    input wire signed [7:0] bias,

    output reg signed [19:0] conv_out,
    output reg valid_out
    );
    
    reg signed [15:0] mult00, mult01, mult02;
    reg signed [15:0] mult10, mult11, mult12;
    reg signed [15:0] mult20, mult21, mult22;
    reg signed [15:0] bias_reg;
    
    reg valid_pipe;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 1. 리셋 동작
            mult00<=0; mult01<=0; mult02<=0;
            mult10<=0; mult11<=0; mult12<=0;
            mult20<=0; mult21<=0; mult22<=0;
            bias_reg <= 0;
            valid_pipe <= 0;
            
            conv_out <= 0;
            valid_out <= 0;
        end else begin
            // 2. 클럭 동기화 동작 (모든 로직은 여기 안에 있어야 함)
            
            // --- Pipeline Stage 1: 곱셈 (Multiplication) ---
            if (valid_in) begin
                mult00 <= $signed({1'b0, w00}) * k00;
                mult01 <= $signed({1'b0, w01}) * k01;
                mult02 <= $signed({1'b0, w02}) * k02;
                
                mult10 <= $signed({1'b0, w10}) * k10;
                mult11 <= $signed({1'b0, w11}) * k11;
                mult12 <= $signed({1'b0, w12}) * k12;
                
                mult20 <= $signed({1'b0, w20}) * k20;
                mult21 <= $signed({1'b0, w21}) * k21;
                mult22 <= $signed({1'b0, w22}) * k22;
                
                bias_reg <= bias;
                valid_pipe <= 1'b1;
            end else begin
                valid_pipe <= 1'b0;
            end
            
            // --- Pipeline Stage 2: 덧셈 (Accumulation) ---
            if (valid_pipe) begin
                conv_out <= mult00 + mult01 + mult02 +
                            mult10 + mult11 + mult12 +
                            mult20 + mult21 + mult22 +
                            bias_reg;
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end
    end
    
endmodule