module qpsk_mapper(clk, reset, inphase, quadrature, valid_in, xn_real, xn_imag, valid_out);
//Define Inputs and Outputs
input  clk, reset, inphase, quadrature, valid_in;
output reg signed [1:0] xn_real;
output reg signed [1:0] xn_imag;
output reg valid_out;

//   Xn = ((I_path + Q_path) - j*(I_path - Q_path)) / 2

always @(posedge clk) begin
    if (reset) begin
        xn_real   <= 2'sd0;
        xn_imag   <= 2'sd0;
        valid_out <= 1'b0;
    end
    else begin
        valid_out <= 1'b0;
        if (valid_in) begin
            case ({inphase, quadrature})
                2'b00: begin
                    xn_real <= -2'sd1;  
                    xn_imag <=  2'sd0;  
                end
                2'b01: begin
                    xn_real <=  2'sd0;  
                    xn_imag <=  2'sd1; 
                end
                2'b10: begin
                    xn_real <=  2'sd0;  
                    xn_imag <= -2'sd1;  
                end
                2'b11: begin
                    xn_real <=  2'sd1;  
                    xn_imag <=  2'sd0;
                end
            endcase
            valid_out <= 1'b1;
        end
        else begin
            xn_real   <= 'x;
            xn_imag   <= 'x;
            valid_out <=  0;
        end
    end
end

endmodule