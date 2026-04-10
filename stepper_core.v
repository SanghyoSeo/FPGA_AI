`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Module Name: stepper_core
// Description: NEMA17(Bipolar) 제어를 위한 2-Phase Excitation (Half Step) 로직
// Tech Lead Comment: 
//   - AXI 인터페이스와 분리하여 순수 로직만 구현 (모듈화)
//   - 파라미터 기반 설계로 재사용성 증대
//////////////////////////////////////////////////////////////////////////////////

module stepper_core(
    input wire clk,             // PL Fabric Clock (e.g., 100MHz or 50MHz)
    input wire rst_n,           // Active Low Reset
    input wire en,              // Motor Enable
    input wire dir,             // Direction (0: CW, 1: CCW)
    input wire [31:0] step_delay, // 속도 제어용 (클럭 카운트 값)
    output reg [3:0] coil_out   // L298N IN1, IN2, IN3, IN4 연결
    );

    // 내부 상태 정의 (Half Step 방식)
    localparam IDLE = 4'd15;
    localparam S0   = 4'd0;
    localparam S1   = 4'd1;
    localparam S2   = 4'd2;
    localparam S3   = 4'd3;
    localparam S4   = 4'd4;
    localparam S5   = 4'd5;
    localparam S6   = 4'd6;
    localparam S7   = 4'd7;

    reg [3:0] current_state;
    reg [31:0] delay_cnt;

    // 타이밍 제어 (속도 조절)
    wire step_tick;
    assign step_tick = (delay_cnt >= step_delay);

    // 1. Delay Counter Block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_cnt <= 0;
        end else if (current_state != IDLE) begin
            if (step_tick) delay_cnt <= 0;
            else delay_cnt <= delay_cnt + 1;
        end else begin
            delay_cnt <= 0;
        end
    end

    // 2. State Machine Block (Next State Logic)
always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            if (!en) begin
                current_state <= IDLE;
            end else if (current_state == IDLE && en) begin
                current_state <= S0;
            end else if (step_tick) begin
                if (dir == 1'b0) begin // CW (0->1->2...->7->0)
                    case (current_state)
                        S0: current_state <= S1;
                        S1: current_state <= S2;
                        S2: current_state <= S3;
                        S3: current_state <= S4;
                        S4: current_state <= S5;
                        S5: current_state <= S6;
                        S6: current_state <= S7;
                        S7: current_state <= S0;
                        default: current_state <= IDLE;
                    endcase
                end else begin         // CCW (0->7->6...->1->0)
                    case (current_state)
                        S0: current_state <= S7;
                        S7: current_state <= S6;
                        S6: current_state <= S5;
                        S5: current_state <= S4;
                        S4: current_state <= S3;
                        S3: current_state <= S2;
                        S2: current_state <= S1;
                        S1: current_state <= S0;
                        default: current_state <= IDLE;
                    endcase
                end
            end
        end
    end

    // 3. Output Logic (L298N에 전달될 신호)
    // 1-2 Phase Excitation (1-2상여자)
    // L298N Pin Mapping: {IN1, IN2, IN3, IN4} -> {A+, A-, B+, B-}
    // 실제 배선: IN1/IN2가 Coil A, IN3/IN4가 Coil B
    // 코드는 {IN1, IN2, IN3, IN4} 순서로 출력
    always @(*) begin
        case (current_state)
            IDLE: coil_out = 4'b0000;
            S0:   coil_out = 4'b1000; 
            S1:   coil_out = 4'b1010; 
            S2:   coil_out = 4'b0010; 
            S3:   coil_out = 4'b0110; 
            S4:   coil_out = 4'b0100; 
            S5:   coil_out = 4'b0101; 
            S6:   coil_out = 4'b0001; 
            S7:   coil_out = 4'b1001; 
            default: coil_out = 4'b0000;
        endcase
    end

endmodule