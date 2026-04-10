`timescale 1ns / 1ps
`default_nettype none

module my_2stepper_ip(
    // AXI4-Lite Signals (기존과 동일)
    input wire  s_axi_aclk,
    input wire  s_axi_aresetn,
    input wire [3:0] s_axi_awaddr,
    input wire  s_axi_awvalid,
    output reg  s_axi_awready,
    input wire [31:0] s_axi_wdata,
    input wire [3:0]  s_axi_wstrb,
    input wire  s_axi_wvalid,
    output reg  s_axi_wready,
    output wire [1:0] s_axi_bresp,
    output reg  s_axi_bvalid,
    input wire  s_axi_bready,
    input wire [3:0] s_axi_araddr,
    input wire  s_axi_arvalid,
    output reg  s_axi_arready,
    output reg [31:0] s_axi_rdata,
    output wire [1:0] s_axi_rresp,
    output reg  s_axi_rvalid,
    input wire  s_axi_rready,

    // [변경] User External Output (8비트: 하위4=M1, 상위4=M2)
    output wire [7:0] coil_out 
    );

    // 내부 레지스터 4개 정의
    reg [31:0] slv_reg0; // 0x00: M1 Ctrl
    reg [31:0] slv_reg1; // 0x04: M1 Speed
    reg [31:0] slv_reg2; // 0x08: M2 Ctrl
    reg [31:0] slv_reg3; // 0x0C: M2 Speed

    // AXI Write Logic
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 0; s_axi_wready <= 0; s_axi_bvalid <= 0;
            slv_reg0 <= 0; slv_reg1 <= 30000; 
            slv_reg2 <= 0; slv_reg3 <= 30000; // 초기값
        end else begin
            if (~s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                s_axi_awready <= 1; s_axi_wready <= 1;
            end else begin
                s_axi_awready <= 0; s_axi_wready <= 0;
            end

            if (s_axi_awready && s_axi_wready) begin
                // 주소 디코딩 (2비트 사용: 00, 01, 10, 11)
                case (s_axi_awaddr[3:2]) 
                    2'b00: slv_reg0 <= s_axi_wdata; // 0x00
                    2'b01: slv_reg1 <= s_axi_wdata; // 0x04
                    2'b10: slv_reg2 <= s_axi_wdata; // 0x08 (Motor 2)
                    2'b11: slv_reg3 <= s_axi_wdata; // 0x0C (Motor 2)
                endcase
                s_axi_bvalid <= 1;
            end else if (s_axi_bready && s_axi_bvalid) begin
                s_axi_bvalid <= 0;
            end
        end
    end
    assign s_axi_bresp = 2'b00;

    // AXI Read Logic
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 0; s_axi_rvalid <= 0; s_axi_rdata <= 0;
        end else begin
            if (~s_axi_arready && s_axi_arvalid) s_axi_arready <= 1;
            else s_axi_arready <= 0;

            if (s_axi_arready && s_axi_arvalid && ~s_axi_rvalid) begin
                s_axi_rvalid <= 1;
                case (s_axi_araddr[3:2])
                    2'b00: s_axi_rdata <= slv_reg0;
                    2'b01: s_axi_rdata <= slv_reg1;
                    2'b10: s_axi_rdata <= slv_reg2;
                    2'b11: s_axi_rdata <= slv_reg3;
                endcase
            end else if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 0;
        end
    end
    assign s_axi_rresp = 2'b00;

    // --- Dual Core Instantiation ---
    
    // Motor 1 (Coil Out [3:0])
    stepper_core u_motor1 (
        .clk        (s_axi_aclk),
        .rst_n      (s_axi_aresetn),
        .en         (slv_reg0[0]),
        .dir        (slv_reg0[1]),
        .step_delay (slv_reg1),
        .coil_out   (coil_out[3:0])
    );

    // Motor 2 (Coil Out [7:4])
    stepper_core u_motor2 (
        .clk        (s_axi_aclk),
        .rst_n      (s_axi_aresetn),
        .en         (slv_reg2[0]),
        .dir        (slv_reg2[1]),
        .step_delay (slv_reg3),
        .coil_out   (coil_out[7:4])
    );

endmodule