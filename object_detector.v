`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/12/18 15:43:31
// Design Name: 
// Module Name: object_detector
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

module object_detector #(
    parameter WIDTH = 640,
    parameter HEIGHT = 480,
    parameter THRESHOLD = 80
)(
    input wire pclk,
    input wire rst_n,
    input wire vsync,
    input wire href,
    input wire [7:0] pixel_in,

    output reg [9:0] center_x,
    output reg [8:0] center_y,
    output reg valid_out
    );

    // 내부 신호 선언
    reg [9:0] x_cnt;
    reg [8:0] y_cnt;
    reg [9:0] min_x, max_x;
    reg [8:0] min_y, max_y;
    reg obj_detected_flag;

    // 엣지 검출을 위한 레지스터
    reg vsync_prev;
    reg href_prev;

    // 와이어 선언
    wire vsync_rise; // 프레임 시작 (0->1)
    wire href_fall;  // 한 줄 끝 (1->0)

    // 엣지 디텍션 로직
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            vsync_prev <= 0;
            href_prev <= 0;
        end else begin
            vsync_prev <= vsync;
            href_prev <= href;
        end
    end
    
    assign vsync_rise = (vsync && !vsync_prev);
    assign href_fall  = (!href && href_prev);

    // =========================================================
    // 메인 로직 (모든 동작을 이 블록 하나로 통합)
    // =========================================================
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            // 리셋 시 초기화
            x_cnt <= 0;
            y_cnt <= 0;
            center_x <= 0;
            center_y <= 0;
            valid_out <= 0;
            min_x <= WIDTH; max_x <= 0;
            min_y <= HEIGHT; max_y <= 0;
            obj_detected_flag <= 0;
        end else begin
            
            // 1. 프레임 시작 (VSYNC Rising)
            if (vsync_rise) begin
                x_cnt <= 0;
                y_cnt <= 0;
                
                // 결과 계산 및 출력
                if (obj_detected_flag) begin
                    center_x <= (min_x + max_x) >> 1;
                    center_y <= (min_y + max_y) >> 1;
                    valid_out <= 1;
                end else begin
                    valid_out <= 0;
                end

                // 다음 프레임 준비 (Min/Max 리셋)
                min_x <= WIDTH; max_x <= 0;
                min_y <= HEIGHT; max_y <= 0;
                obj_detected_flag <= 0;

            end else begin
                // 평상시 동작
                valid_out <= 0; // 1클럭 펄스만 유지

                // 2. 가로(X) 카운팅 및 도형 탐색 (HREF High)
                if (href) begin
                    // X 좌표 증가
                    if (x_cnt < WIDTH - 1) x_cnt <= x_cnt + 1;
                    
                    // 도형 감지 (Thresholding)
                    if (pixel_in < THRESHOLD) begin
                        obj_detected_flag <= 1;

                        if (x_cnt < min_x) min_x <= x_cnt;
                        if (x_cnt > max_x) max_x <= x_cnt;
                        if (y_cnt < min_y) min_y <= y_cnt;
                        if (y_cnt > max_y) max_y <= y_cnt;
                    end
                end else begin
                    // HREF가 꺼지면 X 카운터 리셋
                    x_cnt <= 0;
                end

                // 3. 세로(Y) 카운팅 (HREF Falling Edge)
                // [수정] 이 로직을 여기로 가져와서 Multi-Driver 에러 해결!
                if (href_fall) begin
                    if (y_cnt < HEIGHT - 1) y_cnt <= y_cnt + 1;
                end
            end
        end
    end

endmodule

module object_detector_tb();

    reg pclk = 0;
    reg rst_n = 0;
    reg vsync = 0;
    reg href = 0;
    reg [7:0] pixel_in = 0;

    wire [9:0] center_x;
    wire [8:0] center_y;
    wire valid_out;

    // DUT 연결
    object_detector #(
        .WIDTH(640),
        .HEIGHT(480),
        .THRESHOLD(80)
    ) u_dut (
        .pclk(pclk),
        .rst_n(rst_n),
        .vsync(vsync),
        .href(href),
        .pixel_in(pixel_in),
        .center_x(center_x),
        .center_y(center_y),
        .valid_out(valid_out)
    );

//    always #5 pclk = ~pclk; // 100MHz
    real pclk_half_period = 1000.0 / 24.0 / 2.0; // 24MHz의 반 주기 자동 계산
    
    always #(pclk_half_period) pclk = ~pclk;
    
    // =========================================================
    // ?이미지 메모리 선언
    // =========================================================
    // 640 * 480 = 307,200개의 8비트 데이터를 저장할 공간
    reg [7:0] img_memory [0:640*480-1]; 
    
    integer x, y;
    integer pixel_idx; // 메모리 주소 포인터

    initial begin
        // -----------------------------------------------------
        // 1. 이미지 파일 로드 (파일 경로는 반드시 '/' 슬래시 사용!)
        // -----------------------------------------------------
        // 주의: 아래 경로를 실제 image_data.txt가 있는 경로로 바꿔주세요.
        $readmemh("C:/Users/Admin/Desktop/test_img/image_data.txt", img_memory);
        
        // 1. 초기화
        rst_n = 0;
        vsync = 0;
        href = 0;
        pixel_in = 255;
        pixel_idx = 0; // 인덱스 초기화
        #100;
        rst_n = 1;
        #100;
        
        $display("=== Real Image Simulation Start ===");

        // 2. 프레임 시작
        @(negedge pclk);
        vsync = 0;
        #500;

        // 3. Y 루프 (전체 높이 480)
        for (y = 0; y < 480; y = y + 1) begin
            
            #50; 
            
            // 첫 픽셀 미리 세팅 (HREF 켜기 전)
            // 현재 인덱스(pixel_idx)의 데이터를 가져옴
            pixel_in = img_memory[pixel_idx];

            @(negedge pclk);
            href = 1; 

            // 4. X 루프 (전체 너비 640)
            for (x = 0; x < 640; x = x + 1) begin
                @(negedge pclk); 
                
                // 메모리에서 픽셀값 읽어서 입력에 넣기
                pixel_in = img_memory[pixel_idx];
                
                // 다음 픽셀을 위해 인덱스 증가
                pixel_idx = pixel_idx + 1;
            end

            // 한 줄 끝
            @(negedge pclk);
            href = 0;
            pixel_in = 0; 

            #100; 
        end

        // 5. 프레임 종료 및 결과 확인
        $display("=== Image Scan Done. Triggering VSYNC... ===");
        #1000;

        @(negedge pclk);
        vsync = 1; 
        
        @(posedge pclk);
        @(posedge pclk);
        @(posedge pclk);


        $display("   Detected Center X: %d", center_x);
        $display("   Detected Center Y: %d", center_y);
            
        $finish;
    end
endmodule

//module object_detector_tb();

//    reg pclk = 0;
//    reg rst_n = 0;
//    reg vsync = 0;
//    reg href = 0;
//    reg [7:0] pixel_in = 0;

//    wire [9:0] center_x;
//    wire [8:0] center_y;
//    wire valid_out;

//    // DUT 연결
//    object_detector #(
//        .WIDTH(640),
//        .HEIGHT(480),
//        .THRESHOLD(80)
//    ) u_dut (
//        .pclk(pclk),
//        .rst_n(rst_n),
//        .vsync(vsync),
//        .href(href),
//        .pixel_in(pixel_in),
//        .center_x(center_x),
//        .center_y(center_y),
//        .valid_out(valid_out)
//    );

//    always #5 pclk = ~pclk; // 100MHz

//    integer x, y;

//    initial begin
//        // 1. 초기화
//        rst_n = 0;
//        vsync = 0;
//        href = 0;
//        pixel_in = 255;
//        #100;
//        rst_n = 1;
//        #100;
        
//        $display("=== Simulation Start (Robust Timing) ===");

//        // 2. 프레임 시작
//        // 모든 신호 변경을 'negedge'에서 수행하여 Setup Time 확보
//        @(negedge pclk);
//        vsync = 0;
//        #500;

//        // 3. Y 루프 (0 ~ 205줄)
//        for (y = 0; y <= 205; y = y + 1) begin
            
//            // (1) 한 줄 시작 준비
//            #50; 
            
//            pixel_in = 255;
            
//            // [핵심] HREF를 클럭 내려갈 때 켭니다.
//            @(negedge pclk);
//            href = 1; 

//            // (2) X 루프 (640 픽셀)
//            for (x = 0; x < 640; x = x + 1) begin
//                // [핵심] 데이터도 클럭 내려갈 때 바꿉니다.
//                // 그러면 FPGA는 다음 상승 엣지에서 아주 깨끗한 값을 읽습니다.
//                @(negedge pclk); 
                
//                if (x >= 100 && x < 200 && y >= 100 && y <= 200)
//                    pixel_in = 0;   // 검은 상자
//                else
//                    pixel_in = 255; // 흰 배경
//            end

//            // (3) 한 줄 끝
//            // [핵심] HREF를 끌 때도 negedge에서! -> href_fall 확실하게 발생
//            @(negedge pclk);
//            href = 0;
//            pixel_in = 0;

//            #100; // Horizontal Blanking
//        end

//        // 4. 프레임 종료 및 VSYNC 발생
//        $display("=== Frame Data End. Waiting for Calculation... ===");
//        #1000;

//        @(negedge pclk); // 여기도 negedge!
//        vsync = 1; 
        
//        // 5. 결과 확인
//        @(posedge pclk);
//        @(posedge pclk);
//        @(posedge pclk);

//        if (valid_out) begin
//            $display("? SUCCESS! Output Validated.");
//            $display("   Center X: %d (Expected: 150)", center_x);
//            $display("   Center Y: %d (Expected: 150)", center_y);
//        end else begin
//            $display("? FAIL: No Valid Output.");
//            $display("   Debug info -> Min/Max Y: %d / %d", u_dut.min_y, u_dut.max_y);
//        end
            
//        $finish;
//    end
//endmodule