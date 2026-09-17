module dqpsk_encoder (clk,reset,pkt_start,valid_in,xn_real,xn_imag,out_valid,out_phase);
input clk;
input reset;      
input  valid_in; //This comes from QPSK mapper
input   signed [1:0] xn_real;  
input   signed [1:0] xn_imag;                 
input   pkt_start;  // pulse for 1 cycle at the start of each new packet:
                    // reloads the 4 feedback lanes to 45 deg

output reg  out_valid;
output reg  [2:0]  out_phase ;
   
reg [2:0] in_phase;

always @* begin
    if      (xn_real ==  2'sd1 && xn_imag ==  2'sd0) in_phase = 3'd0;  //  1 , 1*45
    else if (xn_real ==  2'sd0 && xn_imag ==  2'sd1) in_phase = 3'd2;  //  j , 2*45
    else if (xn_real == -2'sd1 && xn_imag ==  2'sd0) in_phase = 3'd4;  // -1 , 4*45 
    else if (xn_real ==  2'sd0 && xn_imag == -2'sd1) in_phase = 3'd6;  // -j , 6*45
    else   in_phase = 3'd0;  // don't-care (valid_in=0)
          end


reg [2:0] mem [0:3];
reg [1:0] lane; //go from 0 → 1 → 2 → 3 → 0
integer   k;

always @(posedge clk) begin
        if (reset) begin
            for (k = 0; k < 4; k = k + 1) mem[k] <= 3'd1; //Initialize to exp(j*pi/4)
            lane      <= 2'd0;
            out_valid <= 1'b0;
            out_phase <= 3'd0;
                   end
        else begin
            if (pkt_start) begin
            for (k = 0; k < 4; k = k + 1) mem[k] <= 3'd1; // reload per packet
            lane      <= 2'd0;
            out_valid <= 1'b0;
                             end
            else begin
            out_valid <= valid_in;
            if (valid_in) begin
                // complex multiply == phase add mod 8 (free 3-bit wraparound)
                out_phase <= in_phase + mem[lane];
                mem[lane] <= in_phase + mem[lane];
                lane      <= lane + 2'd1;
            end
        end
    end
    end

endmodule