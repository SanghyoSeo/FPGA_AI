`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/07/06 21:22:50
// Design Name: 
// Module Name: i2c_interface
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

`default_nettype wire
module i2c_interface(
    input clk_50Mhz,
    input rst,
    output siod,
    output reg sioc,
    output taken,
    input send,
    input [7:0] id,
    input [7:0] register,
    input [7:0] value
    );
    
    localparam IDLE=0,
               BUSY=1;
    
    reg curr_state, next_state;
    always @ (posedge clk_50Mhz)
        if(rst==1) curr_state<=IDLE;
        else curr_state<=next_state;
        
    wire sent;
    always @ *
    begin
        next_state=curr_state;
        case(curr_state)
        IDLE: if(send==1) next_state=BUSY;
        BUSY: if(sent==1) next_state=IDLE;
        endcase
    end
    
    wire busy;
    assign busy = (curr_state==BUSY);
    
    reg [7:0] cnt_200KHz;
    always @ (posedge clk_50Mhz)
    begin
        if(rst==1) cnt_200KHz<=0;
        else if(busy) begin
            cnt_200KHz<=cnt_200KHz+1;
            if(cnt_200KHz==255) 
                cnt_200KHz<=0;
        end
        else cnt_200KHz<=0;
     end
        
    reg [6:0] busy_state;    
    always @ (posedge clk_50Mhz)
    begin
        if(rst==1) busy_state<=0;
        else if(busy) begin
            if(cnt_200KHz==255) begin
                busy_state<=busy_state+1;
                if(busy_state==31) 
                    busy_state<=0;
             end
        end
        else busy_state<=0;
     end
     
     reg [31:0] data_sr;
     always @ (posedge clk_50Mhz)
     begin
        if(rst==1) data_sr<=0;
        else if(send==1 && busy_state==1 && cnt_200KHz==0) 
            data_sr<={3'b100,id,1'b0,register,1'b0,value,1'b0,2'b01};
        else if(cnt_200KHz==255)
            data_sr<={data_sr[30:0], 1'b1};
     end
     
     assign taken = (send==1 && busy_state==1 && cnt_200KHz==0);
     
     assign siod = (busy_state==12 || busy_state==21 || busy_state==30)?1'bz:data_sr[31];
          
     assign sent = (busy_state==31 && cnt_200KHz==255);
     
     always @ *
     begin
        if(busy_state<=2||busy_state==32) sioc=1;
        else if(busy_state==3) sioc=0;
        else if(busy_state==31) 
            sioc=(cnt_200KHz>=64);
        else begin
            sioc=(cnt_200KHz>=64 && cnt_200KHz<=192);
        end
     end
        
endmodule

module i2c_interface_2(
    input clk_50Mhz,
    output siod,
    output reg sioc,
    output taken,
    input send,
    input [7:0] id,
    input [7:0] register1,
    input [7:0] value
    );
    
    localparam IDLE=0,
               BUSY=1;
    
    reg curr_state = IDLE, next_state=IDLE;
    always @ (posedge clk_50Mhz)
        curr_state<=next_state;
        
    wire sent;
    always @ *
    begin
        next_state=curr_state;
        case(curr_state)
        IDLE: if(send==1) next_state=BUSY;
        BUSY: if(sent==1) next_state=IDLE;
        endcase
    end
    
    wire busy;
    assign busy = (curr_state==BUSY);
    
    reg [7:0] cnt_200KHz;
    always @ (posedge clk_50Mhz)
    begin
        if(busy) begin
            cnt_200KHz<=cnt_200KHz+1;
            if(cnt_200KHz==255) 
                cnt_200KHz<=0;
        end
        else cnt_200KHz<=0;
     end
        
    reg [6:0] busy_state;    
    always @ (posedge clk_50Mhz)
    begin
        if(busy) begin
            if(cnt_200KHz==255) begin
                busy_state<=busy_state+1;
                if(busy_state==31) 
                    busy_state<=0;
             end
        end
        else busy_state<=0;
     end
     
     reg [31:0] data_sr;
     always @ (posedge clk_50Mhz)
     begin
        if(send==1 && busy_state==1 && cnt_200KHz==0) 
            data_sr<={3'b100,id,1'b0,register1,1'b0,value,1'b0,2'b01};
        else if(cnt_200KHz==255)
            data_sr<={data_sr[30:0], 1'b1};
     end
     
     assign taken = (send==1 && busy_state==1 && cnt_200KHz==0);
     
     assign siod = (busy_state==12 || busy_state==21 || busy_state==30)?1'bz:data_sr[31];
          
     assign sent = (busy_state==31 && cnt_200KHz==255);
     
     always @ *
     begin
        if(busy_state<=2/*||busy_state==32*/) sioc=1;
        else if(busy_state==3) sioc=0;
        else if(busy_state==31) 
            sioc=(cnt_200KHz>=64);
        else begin
            sioc=(cnt_200KHz>=64 && cnt_200KHz<=192);
        end
     end
        
endmodule

module i2c_interface_2_tb;

    reg clk_50Mhz=0;
    wire taken;
    wire send = 1;
    wire [7:0] id = 8'h42;
    wire [7:0] register1 = 8'h12;
    wire [7:0] value = 8'h80;
    
    i2c_interface_2 uut(clk_50Mhz,siod,sioc,taken,send,id,register1,value);
    
    always #10 clk_50Mhz = ~clk_50Mhz;

endmodule