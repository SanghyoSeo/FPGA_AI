`timescale 1ns / 1ps
`default_nettype none

module conv_layer_top #(
    parameter IMG_WIDTH = 640,
    parameter IMG_HEIGHT = 480,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [DATA_WIDTH-1:0] data_in,
    
    // [수정] 4채널 가중치 입력 (파라미터 포트 확장)
    // Channel 0
    input wire signed [7:0] k00_ch0, k01_ch0, k02_ch0, k10_ch0, k11_ch0, k12_ch0, k20_ch0, k21_ch0, k22_ch0, bias_ch0,
    // Channel 1
    input wire signed [7:0] k00_ch1, k01_ch1, k02_ch1, k10_ch1, k11_ch1, k12_ch1, k20_ch1, k21_ch1, k22_ch1, bias_ch1,
    // Channel 2
    input wire signed [7:0] k00_ch2, k01_ch2, k02_ch2, k10_ch2, k11_ch2, k12_ch2, k20_ch2, k21_ch2, k22_ch2, bias_ch2,
    // Channel 3
    input wire signed [7:0] k00_ch3, k01_ch3, k02_ch3, k10_ch3, k11_ch3, k12_ch3, k20_ch3, k21_ch3, k22_ch3, bias_ch3,

    // [수정] 결과 출력도 4개 채널
    output wire valid_out,
    output wire signed [19:0] layer_out_0,
    output wire signed [19:0] layer_out_1,
    output wire signed [19:0] layer_out_2,
    output wire signed [19:0] layer_out_3
    );

    // --- 공통 라인 버퍼 및 윈도우 생성 (자원 절약: 1개만 씀) ---
    wire [7:0] line0, line1, line2;
    wire [7:0] w00, w01, w02, w10, w11, w12, w20, w21, w22;
    wire win_valid;

    line3_buffer #(.WIDTH(IMG_WIDTH)) u_line_buf (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .data_in(data_in),
        .line0_data(line0), .line1_data(line1), .line2_data(line2)
    );

    window_gen_3x3 #(.IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT)) u_window_gen (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .line0_in(line0), .line1_in(line1), .line2_in(line2),
        .w00(w00), .w01(w01), .w02(w02), .w10(w10), .w11(w11), .w12(w12), .w20(w20), .w21(w21), .w22(w22),
        .calc_valid(win_valid)
    );

    // --- [핵심] 4개의 병렬 필터 (Parallel Conv) ---
    wire signed [19:0] cr0, cr1, cr2, cr3;
    wire cv0, cv1, cv2, cv3;

    // Filter 0
    conv_calc u_c0 (.clk(clk), .rst_n(rst_n), .valid_in(win_valid), 
        .w00(w00), .w01(w01), .w02(w02), .w10(w10), .w11(w11), .w12(w12), .w20(w20), .w21(w21), .w22(w22), 
        .k00(k00_ch0), .k01(k01_ch0), .k02(k02_ch0), .k10(k10_ch0), .k11(k11_ch0), .k12(k12_ch0), .k20(k20_ch0), .k21(k21_ch0), .k22(k22_ch0), .bias(bias_ch0), 
        .conv_out(cr0), .valid_out(cv0));
        
    // Filter 1
    conv_calc u_c1 (.clk(clk), .rst_n(rst_n), .valid_in(win_valid), 
        .w00(w00), .w01(w01), .w02(w02), .w10(w10), .w11(w11), .w12(w12), .w20(w20), .w21(w21), .w22(w22), 
        .k00(k00_ch1), .k01(k01_ch1), .k02(k02_ch1), .k10(k10_ch1), .k11(k11_ch1), .k12(k12_ch1), .k20(k20_ch1), .k21(k21_ch1), .k22(k22_ch1), .bias(bias_ch1), 
        .conv_out(cr1), .valid_out(cv1));

    // Filter 2
    conv_calc u_c2 (.clk(clk), .rst_n(rst_n), .valid_in(win_valid), 
        .w00(w00), .w01(w01), .w02(w02), .w10(w10), .w11(w11), .w12(w12), .w20(w20), .w21(w21), .w22(w22), 
        .k00(k00_ch2), .k01(k01_ch2), .k02(k02_ch2), .k10(k10_ch2), .k11(k11_ch2), .k12(k12_ch2), .k20(k20_ch2), .k21(k21_ch2), .k22(k22_ch2), .bias(bias_ch2), 
        .conv_out(cr2), .valid_out(cv2));

    // Filter 3
    conv_calc u_c3 (.clk(clk), .rst_n(rst_n), .valid_in(win_valid), 
        .w00(w00), .w01(w01), .w02(w02), .w10(w10), .w11(w11), .w12(w12), .w20(w20), .w21(w21), .w22(w22), 
        .k00(k00_ch3), .k01(k01_ch3), .k02(k02_ch3), .k10(k10_ch3), .k11(k11_ch3), .k12(k12_ch3), .k20(k20_ch3), .k21(k21_ch3), .k22(k22_ch3), .bias(bias_ch3), 
        .conv_out(cr3), .valid_out(cv3));

    // --- [병렬 Pooling] 4개 채널 모두 줄이기 ---
    wire dum; // valid는 하나만 써도 됨 (동기화됨)
    pooling_relu #(.DATA_WIDTH(20), .IMG_WIDTH(IMG_WIDTH-2)) u_pool0 (.clk(clk), .rst_n(rst_n), .valid_in(cv0), .data_in(cr0), .valid_out(valid_out), .data_out(layer_out_0));
    pooling_relu #(.DATA_WIDTH(20), .IMG_WIDTH(IMG_WIDTH-2)) u_pool1 (.clk(clk), .rst_n(rst_n), .valid_in(cv1), .data_in(cr1), .valid_out(dum), .data_out(layer_out_1));
    pooling_relu #(.DATA_WIDTH(20), .IMG_WIDTH(IMG_WIDTH-2)) u_pool2 (.clk(clk), .rst_n(rst_n), .valid_in(cv2), .data_in(cr2), .valid_out(dum), .data_out(layer_out_2));
    pooling_relu #(.DATA_WIDTH(20), .IMG_WIDTH(IMG_WIDTH-2)) u_pool3 (.clk(clk), .rst_n(rst_n), .valid_in(cv3), .data_in(cr3), .valid_out(dum), .data_out(layer_out_3));

endmodule
module conv_layer_top_tb();

    reg clk = 0;
    reg rst_n = 0;
    reg valid_in = 0;
    reg [7:0] data_in = 0;
    
    reg signed [7:0] k00, k01, k02;
    reg signed [7:0] k10, k11, k12;
    reg signed [7:0] k20, k21, k22;
    reg signed [7:0] bias;
    
    wire valid_out;
    wire signed [19:0] conv_out; // 이름은 conv_out이지만 Pooling 결과가 담김

    localparam IMG_W = 640;
    localparam IMG_H = 480;

    // DUT 연결
    conv_layer_top #(
        .IMG_WIDTH(IMG_W),
        .IMG_HEIGHT(IMG_H)
    ) u_top (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .data_in(data_in),
        .k00(k00), .k01(k01), .k02(k02),
        .k10(k10), .k11(k11), .k12(k12),
        .k20(k20), .k21(k21), .k22(k22),
        .bias(bias),
        
        .valid_out(valid_out),
        .layer_out(conv_out) // [중요] 포트 이름 매핑 확인!
    );

    // 24MHz 클럭
    always #21 clk = ~clk;

    reg [7:0] img_mem [0:IMG_W*IMG_H-1];
    integer pixel_idx;
    integer r, c;
    integer file_handle;

    initial begin
        // 경로 확인 필수!
        $readmemh("C:/Users/Admin/Desktop/test_img/image_data.txt", img_mem);
        file_handle = $fopen("C:/Users/Admin/Desktop/test_img/output_data.txt", "w");
        
        rst_n = 0;
        valid_in = 0;
        pixel_idx = 0;
        
        // Sobel Filter
        k00 = -1; k01 = 0; k02 = 1;
        k10 = -2; k11 = 0; k12 = 2;
        k20 = -1; k21 = 0; k22 = 1;
        bias = 0;

        #100;
        rst_n = 1;
        #100;

        $display("=== Simulation Start ===");

        @(negedge clk);
        for (r = 0; r < IMG_H; r = r + 1) begin
            for (c = 0; c < IMG_W; c = c + 1) begin
                valid_in = 1;
                data_in = img_mem[pixel_idx];
                pixel_idx = pixel_idx + 1;
                @(negedge clk);
            end
            valid_in = 0;
            repeat(10) @(negedge clk); 
        end
        
        $display("=== All Data Transferred ===");
        #2000; // Pooling Latency 고려해서 좀 더 기다림
        
        $fclose(file_handle);
        $finish;
    end

    // 파일 쓰기
    always @(posedge clk) begin
        if (valid_out) begin
            $fdisplay(file_handle, "%d", conv_out);
        end
    end

endmodule