`timescale 1ns / 1ps
`default_nettype none

module line3_buffer #(
    parameter WIDTH = 640
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [7:0] data_in,
    
    output reg [7:0] line0_data,
    output reg [7:0] line1_data,
    output reg [7:0] line2_data
    );

    // BRAM 추론을 위한 메모리 배열
    reg [7:0] mem0 [0:WIDTH-1];
    reg [7:0] mem1 [0:WIDTH-1];
    
    reg [9:0] ptr;

    // =============================================================
    // [Block 1] 메모리 & 데이터 처리 (Synchronous - Reset 없음)
    // BRAM은 비동기 리셋을 지원하지 않으므로, 읽기/쓰기는 여기서만 처리
    // =============================================================
    always @(posedge clk) begin
        if (valid_in) begin
            // 1. Read (메모리에서 읽기)
            line0_data <= mem1[ptr];
            line1_data <= mem0[ptr];
            line2_data <= data_in; // 입력 데이터 바로 통과

            // 2. Write (메모리에 쓰기)
            mem1[ptr] <= mem0[ptr]; // Shift
            mem0[ptr] <= data_in;   // New Input
        end
    end

    // =============================================================
    // [Block 2] 포인터 제어 (Asynchronous Reset 지원)
    // 주소값(ptr)은 리셋이 필요하므로 따로 처리
    // =============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ptr <= 0;
            // 데이터(line0_data 등)는 Block 1에서 제어하므로 여기서 건드리면 안 됨 (Multi-driver 에러 방지)
        end else if (valid_in) begin
            if (ptr == WIDTH - 1) 
                ptr <= 0;
            else 
                ptr <= ptr + 1;
        end
    end
    
endmodule