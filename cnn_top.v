`timescale 1ns / 1ps
`default_nettype none

module cnn_top #(
    parameter IMG_WIDTH  = 28,  // 시뮬레이션/테스트용
    parameter IMG_HEIGHT = 28,
    parameter DATA_WIDTH = 8,
    parameter FC_INPUTS  = 169
)(
    input wire clk,           // 시스템 클럭 (예: 125MHz or 100MHz)
    input wire clk_pix,       // 픽셀 클럭 (25MHz, Clock Wizard에서 생성되어 들어옴)
    input wire clk_tmds,      // HDMI 고속 클럭 (250MHz, Clock Wizard에서 생성되어 들어옴)
    input wire rst_n,
    
    // [핵심] 스위치 입력 (System Top에서 연결해줘야 함)
    // sw[0]: 가이드라인 박스 ON/OFF
    // sw[1]: 결과 고정 (Freeze)
    // sw[2]: CNN 연산 시작 & 텍스트 출력 ON
    input wire [2:0] sw,

    // 카메라/영상 입력
    input wire cam_href,      // HSYNC 역할
    input wire cam_vsync,     // VSYNC 역할
    input wire [7:0] cam_data, // 영상 데이터 (Grayscale 가정)

    // CNN용 가중치 입력 (상위 모듈에서 상수로 연결하거나 레지스터로 설정)
    input wire signed [DATA_WIDTH-1:0] k00, k01, k02,
    input wire signed [DATA_WIDTH-1:0] k10, k11, k12,
    input wire signed [DATA_WIDTH-1:0] k20, k21, k22,
    input wire signed [DATA_WIDTH-1:0] bias,

    // HDMI 출력 포트
    output wire [2:0] tmds_data_p, tmds_data_n,
    output wire tmds_clk_p, tmds_clk_n,
    
    // 디버깅용 LED (선택사항)
    output wire [2:0] led_check
);

    // =============================================================
    // 1. 내부 신호 선언
    // =============================================================
    wire conv_valid;
    wire signed [19:0] conv_data;
    
    wire class_valid;
    wire signed [31:0] score_c, score_t, score_s;
    
    // 결과 처리용
    reg [1:0] current_winner;   // 실시간 1등
    reg [1:0] final_result;     // 최종 표시용 (Freeze 적용됨)
    reg [2:0] osd_msg_code;     // RGB 모듈로 보낼 코드

    // 영상 데이터 처리 (8bit -> 12bit 확장)
    wire [11:0] osd_din;
    assign osd_din = {cam_data[7:4], cam_data[7:4], cam_data[7:4]}; // 흑백을 RGB로

    // =============================================================
    // 2. CNN 연산 블록 (Conv -> FC)
    // =============================================================
    
    // (1) Conv Layer
    conv_layer_top #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_conv_layer (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(cam_href),   // 영상 들어올 때 valid라고 가정 (실제 타이밍 맞게 조정 필요)
        .data_in(cam_data),
        
        .k00(k00), .k01(k01), .k02(k02),
        .k10(k10), .k11(k11), .k12(k12),
        .k20(k20), .k21(k21), .k22(k22),
        .bias(bias),
        
        .valid_out(conv_valid),
        .layer_out(conv_data)
    );

    // (2) FC Layer (수정한 버전 사용)
    fc_layer #(
        .DATA_WIDTH(20),
        .NUM_INPUTS(FC_INPUTS)
    ) u_fc_layer (
        .clk(clk),
        .rst_n(rst_n),
        .en(sw[2]),            // SW2가 켜져야 연산 수행
        .valid_in(conv_valid),
        .data_in(conv_data),
        
        .valid_out(class_valid),
        .score0(score_c),
        .score1(score_t),
        .score2(score_s)
    );

    // =============================================================
    // 3. 결과 판단 및 스위치 제어 로직 (SW1 Freeze)
    // =============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            final_result <= 0;
            current_winner <= 0;
            osd_msg_code <= 0;
        end else begin
            // A. 가장 점수가 높은 도형 찾기
            if (score_c >= score_t && score_c >= score_s) current_winner <= 2'd0; // 원
            else if (score_t >= score_c && score_t >= score_s) current_winner <= 2'd1; // 삼각형
            else current_winner <= 2'd2; // 사각형

            // B. SW1 (Freeze) 로직
            if (sw[1] == 1'b0) begin
                // 스위치 꺼짐 -> 실시간 결과 반영
                final_result <= current_winner;
            end 
            // 스위치 켜짐(1) -> else를 안 씀으로써 이전 값 유지 (Latch/Freeze)

            // C. RGB 모듈용 메시지 코드로 변환
            case (final_result)
                2'd0: osd_msg_code <= 3'b001; // CIR
                2'd1: osd_msg_code <= 3'b010; // TRI
                2'd2: osd_msg_code <= 3'b011; // REC
                default: osd_msg_code <= 3'b000;
            endcase
        end
    end

    // LED로 간단 디버깅 (현재 무슨 도형인지)
    assign led_check = osd_msg_code; 

    // =============================================================
    // 4. 화면 출력 (RGB OSD + HDMI)
    // =============================================================
    
    wire [7:0] vga_r, vga_g, vga_b;

    // (1) RGB 모듈 (VHDL) 인스턴스
    // *주의: RGB.vhd 파일이 프로젝트 소스에 포함되어 있어야 함
    RGB u_osd_inst (
        .Din(osd_din),
        .Nblank(cam_href),     // Active Video 신호
        .CLK(clk_pix),         // 25MHz 픽셀 클럭
        .Hsync(cam_href),      // (타이밍에 맞게 HSYNC 연결)
        .Vsync(cam_vsync),
        
        // 데이터 연결
        .msg_code(osd_msg_code),
        .sw(sw),               // SW0, SW2 기능 사용
        .score_c(score_c),
        .score_t(score_t),
        .score_s(score_s),
        
        .R(vga_r),
        .G(vga_g),
        .B(vga_b),
        
        // 사용 안 함
        .x_center(10'd0), .y_center(10'd0), .target_x(10'd0), .target_y(10'd0)
    );

    // (2) HDMI 변환기
    VGA2HDMI u_hdmi_tx (
        .pixclk(clk_pix),
        .clk_TMDS(clk_tmds),
        .VSYNC(cam_vsync),
        .HSYNC(cam_href),     // (실제 VGA 타이밍에 맞는지 확인 필요)
        .ACTIVE(cam_href),
        .red(vga_r),
        .green(vga_g),
        .blue(vga_b),
        .TMDSp(tmds_data_p), .TMDSn(tmds_data_n),
        .TMDSp_clock(tmds_clk_p), .TMDSn_clock(tmds_clk_n)
    );

endmodule