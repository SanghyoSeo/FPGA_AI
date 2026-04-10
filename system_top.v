`timescale 1ns / 1ps
`default_nettype none

module system_top(
    input  wire clk125,        
    input  wire [3:0] sw,        
    input  wire [3:0] btn, // [중요] XDC에서 btn[0]~btn[3] 매핑 필수
    output wire [2:0] TMDSp, TMDSn,
    output wire TMDSp_clock, TMDSn_clock,
    input  wire ov7670_pclk, ov7670_vsync, ov7670_href,
    input  wire [7:0] ov7670_data,
    output wire ov7670_xclk, ov7670_sioc, 
    inout  wire ov7670_siod,
    output wire ov7670_pwdn, ov7670_reset,
    output wire [3:0] led
);

    // 1. Clock Generation
    wire clk100, clk25, clk50, clk250, locked;
    assign locked = 1'b1;
    clk_wiz_0 u_clock_gen (.clk_in1(clk125), .clk_out1(clk100), .clk_out2(clk25), .clk_out3(clk50));
    clk_wiz_1 u_hdmi_clk_gen (.clk_in1(clk25), .clk_out1(clk250));

    // 2. Camera Capture (Auto Config)
    wire config_finished;
    ov7670_controller u_cam_ctrl (
        .clk(clk50), .resend(1'b0), .config_finished(config_finished),
        .sioc(ov7670_sioc), .siod(ov7670_siod), .reset(ov7670_reset), 
        .pwdn(ov7670_pwdn), .xclk(ov7670_xclk)      
    );
    assign led[0] = config_finished; 

    wire [18:0] capture_addr;
    wire [11:0] capture_data;
    wire capture_we, capture_we_base;
    wire [9:0] cap_center_x, cap_center_y;
    
    // Camera Capture Logic
    ov7670_capture u_capture (
        .pclk(ov7670_pclk), .rez_160x120(1'b0), .rez_320x240(1'b0), 
        .sw(2'b00), .btn_up(1'b0), .btn_down(1'b0),
        .vsync(ov7670_vsync), .href(ov7670_href), .d(ov7670_data),
        .addr(capture_addr), .dout(capture_data), .we(capture_we_base),
        .x_center(cap_center_x), .y_center(cap_center_y) 
    );
    assign capture_we = capture_we_base && (sw[0] == 1'b0);

    // =========================================================================
    // [보정 로직] 버튼 입력으로 가중치(Bias) 조절
    // BTN0: Reset, BTN1: I(+), BTN2: O(+), BTN3: W(+)
    // =========================================================================
    reg signed [31:0] adj_bias_0 = 0; // O Class 보정치
    reg signed [31:0] adj_bias_1 = 0; // W Class 보정치
    reg signed [31:0] adj_bias_2 = 0; // I Class 보정치
    
    reg [3:0] prev_btn;
    reg prev_vsync_sig; 

    always @(posedge clk25) begin
        prev_vsync_sig <= ov7670_vsync;
        
        // VSYNC Rising Edge (60Hz)마다 버튼 확인
        if (ov7670_vsync && !prev_vsync_sig) begin
            if (btn[0]) begin
                // BTN0: RESET
                adj_bias_0 <= 0;
                adj_bias_1 <= 0;
                adj_bias_2 <= 0;
            end else begin
                // BTN1: Increase I (Triangle)
                if (btn[1] && !prev_btn[1]) adj_bias_2 <= adj_bias_2 + 10;
                
                // BTN2: Increase O (Circle)
                if (btn[2] && !prev_btn[2]) adj_bias_0 <= adj_bias_0 + 10;
                
                // BTN3: Increase W (Square)
                if (btn[3] && !prev_btn[3]) adj_bias_1 <= adj_bias_1 + 10;
            end
            prev_btn <= btn;
        end
    end
    // =========================================================================

    // 3. Pre-processing
    localparam integer RATIO = 4; 
    wire [9:0] curr_x = capture_addr % 640;
    wire [9:0] curr_y = capture_addr / 640;
    
    wire [9:0] half_window_safe = 60; 
    wire x_in_range_raw = (curr_x > cap_center_x) ? ((curr_x - cap_center_x) < half_window_safe) : ((cap_center_x - curr_x) < half_window_safe);
    wire y_in_range = (curr_y > cap_center_y) ? ((curr_y - cap_center_y) < 14 * RATIO) : ((cap_center_y - curr_y) < 14 * RATIO);
    wire [9:0] roi_start_x = (cap_center_x > half_window_safe) ? (cap_center_x - half_window_safe) : 0;
    wire [9:0] roi_start_y = (cap_center_y > 56) ? (cap_center_y - 56) : 0;
    wire sampling_hit = (((curr_x - roi_start_x) % RATIO) == 0) && (((curr_y - roi_start_y) % RATIO) == 0);

    reg [5:0] samples_per_line;
    always @(posedge ov7670_pclk) begin
        if (curr_x < roi_start_x) samples_per_line <= 0;
        else if (capture_we && x_in_range_raw && sampling_hit) samples_per_line <= samples_per_line + 1;
    end
    wire strict_valid = capture_we && x_in_range_raw && y_in_range && sampling_hit && (samples_per_line < 28);
    wire raw_bin = (capture_data[11] == 1'b1);
    
    // Smear Logic (번짐 효과)
    reg [2:0] smear_cnt;
    always @(posedge ov7670_pclk) begin
        if (raw_bin) smear_cnt <= 3'd3; 
        else if (smear_cnt > 0) smear_cnt <= smear_cnt - 1; 
    end
    wire filtered_bin = raw_bin | (smear_cnt > 0);
    wire cnn_valid_in = strict_valid; 
    wire [7:0] cnn_pixel_in = filtered_bin ? 8'd1 : 8'd0; 

    // Debug Memory
    reg [0:0] debug_mem [0:783]; 
    reg [9:0] dbg_wr_ptr;
    always @(posedge ov7670_pclk) begin
        if (ov7670_vsync) dbg_wr_ptr <= 0;
        else if (cnn_valid_in && dbg_wr_ptr < 784) begin
            debug_mem[dbg_wr_ptr] <= filtered_bin;
            dbg_wr_ptr <= dbg_wr_ptr + 1;
        end
    end

    // 4. CNN Core
    wire conv_valid, class_valid;
    wire signed [19:0] conv_data_0, conv_data_1, conv_data_2, conv_data_3;
    wire signed [31:0] score_c, score_s, score_t; 

    // Conv Layer (파이썬 학습값)
    conv_layer_top #(
        .IMG_WIDTH(28), .IMG_HEIGHT(28), .DATA_WIDTH(8)
    ) u_conv_layer (
        .clk(ov7670_pclk), .rst_n(locked),
        .valid_in(cnn_valid_in), .data_in(cnn_pixel_in),

        // Ch0
        .k00_ch0(6), .k01_ch0(5), .k02_ch0(4),
        .k10_ch0(-2), .k11_ch0(0), .k12_ch0(2),
        .k20_ch0(-6), .k21_ch0(-7), .k22_ch0(-6), .bias_ch0(0),
        // Ch1
        .k00_ch1(-4), .k01_ch1(-6), .k02_ch1(-8),
        .k10_ch1(4), .k11_ch1(1), .k12_ch1(-4),
        .k20_ch1(4), .k21_ch1(4), .k22_ch1(7), .bias_ch1(-1),
        // Ch2
        .k00_ch2(4), .k01_ch2(0), .k02_ch2(5),
        .k10_ch2(2), .k11_ch2(0), .k12_ch2(1),
        .k20_ch2(0), .k21_ch2(0), .k22_ch2(1), .bias_ch2(-6),
        // Ch3
        .k00_ch3(0), .k01_ch3(0), .k02_ch3(-5),
        .k10_ch3(-10), .k11_ch3(-2), .k12_ch3(0),
        .k20_ch3(0), .k21_ch3(2), .k22_ch3(9), .bias_ch3(0),

        .valid_out(conv_valid),
        .layer_out_0(conv_data_0), .layer_out_1(conv_data_1),
        .layer_out_2(conv_data_2), .layer_out_3(conv_data_3)
    );

    // [핵심 수정] FC Layer 연결 (O와 I 교차 연결)
    fc_layer #(
        .DATA_WIDTH(20), .NUM_INPUTS(676)
    ) u_fc_layer (
        .clk(ov7670_pclk), .rst_n(locked), .en(sw[1]), 
        .valid_in(conv_valid),
        
        // [입력 교차] I버튼(adj_bias_2) -> Class 0 입력
        //             O버튼(adj_bias_0) -> Class 2 입력
        .adj_bias_0(adj_bias_2), 
        .adj_bias_1(adj_bias_1), 
        .adj_bias_2(adj_bias_0),

        .data_in_0(conv_data_0), .data_in_1(conv_data_1),
        .data_in_2(conv_data_2), .data_in_3(conv_data_3),
        
        .valid_out(class_valid), 
        
        // [출력 교차] Class 0 결과 -> Triangle(I) 점수
        //             Class 2 결과 -> Circle(O) 점수
        .score0(score_t), 
        .score1(score_s), 
        .score2(score_c)
    );

    // 5. Voting Logic
    localparam integer VOTE_PERIOD = 25000000; 
    reg [31:0] vote_timer;
    reg [31:0] cnt_o, cnt_w, cnt_i; 
    reg [2:0]  disp_shape_code;

    always @(posedge ov7670_pclk) begin
        if (sw[0] == 1'b0) begin 
            if (vote_timer >= VOTE_PERIOD) begin
                if (cnt_o >= cnt_w && cnt_o >= cnt_i) disp_shape_code <= 3'd1; 
                else if (cnt_w >= cnt_o && cnt_w >= cnt_i) disp_shape_code <= 3'd2; 
                else disp_shape_code <= 3'd3; 

                vote_timer <= 0;
                cnt_o <= 0; cnt_w <= 0; cnt_i <= 0;
            end 
            else begin
                vote_timer <= vote_timer + 1;
                if (class_valid) begin
                    if (score_c >= score_s && score_c >= score_t) cnt_o <= cnt_o + 1;
                    else if (score_s >= score_c && score_s >= score_t) cnt_w <= cnt_w + 1;
                    else cnt_i <= cnt_i + 1;
                end
            end
        end
    end
    assign led[3:1] = disp_shape_code; 

    // Video Output
    wire [18:0] frame_addr_read;
    wire [11:0] frame_pixel_read;
    wire vga_hsync, vga_vsync, vga_active;
    wire [7:0] vga_r, vga_g, vga_b;
    
    frame_buffer u_frame_buffer (
        .clka(ov7670_pclk), .wea(capture_we), .addra(capture_addr), .dina(capture_data),
        .clkb(clk25), .addrb(frame_addr_read), .doutb(frame_pixel_read)
    );
    
    reg [9:0] vga_x = 0, vga_y = 0;
    always @(posedge clk25) begin
        if (vga_active) begin
            if (vga_x == 639) begin vga_x <= 0; if (vga_y == 479) vga_y <= 0; else vga_y <= vga_y + 1; end 
            else vga_x <= vga_x + 1;
        end else if (!vga_vsync) begin vga_x <= 0; vga_y <= 0; end
    end
    assign frame_addr_read = vga_y * 640 + vga_x;

    wire debug_pixel_on;
    wire [9:0] dbg_x_rel = vga_x - 580;
    wire [9:0] dbg_y_rel = vga_y - 50;
    wire [9:0] dbg_read_addr = (dbg_y_rel[9:1]) * 28 + (dbg_x_rel[9:1]); 
    assign debug_pixel_on = (vga_x >= 580 && vga_x < 580 + 56 && vga_y >= 50 && vga_y < 50 + 56) ? 
                            debug_mem[dbg_read_addr] : 1'b0;

    VGA u_vga_timing (
        .CLK25(clk25), .rez_160x120(1'b0), .rez_320x240(1'b0), 
        .Hsync(vga_hsync), .Vsync(vga_vsync), .Nblank(vga_active)
    );

    wire [3:0] osd_sw_mapped = {sw[3], 1'b1, sw[1], sw[0]};

    RGB u_osd (
        .Din(frame_pixel_read), .Nblank(vga_active), .CLK(clk25),
        .Hsync(vga_hsync), .Vsync(vga_vsync),
        .msg_code(disp_shape_code), .sw(osd_sw_mapped), 
        .debug_pixel(debug_pixel_on),
        .score_c(score_c), .score_t(score_t), .score_s(score_s), 
        .R(vga_r), .G(vga_g), .B(vga_b),
        .target_x(cap_center_x), .target_y(cap_center_y),
        .x_center(10'd0), .y_center(10'd0)
    );

    VGA2HDMI u_hdmi (
        .pixclk(clk25), .clk_TMDS(clk250), 
        .VSYNC(vga_vsync), .HSYNC(vga_hsync), .ACTIVE(vga_active),
        .red(vga_r), .green(vga_g), .blue(vga_b),
        .TMDSp(TMDSp), .TMDSn(TMDSn), 
        .TMDSp_clock(TMDSp_clock), .TMDSn_clock(TMDSn_clock)
    );

endmodule