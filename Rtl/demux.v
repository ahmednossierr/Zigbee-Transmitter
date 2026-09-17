module demux (clk, reset, start_demux, padded_data, total_bits,
              in_phase, quadrature, valid_out);

input clk, reset, start_demux;
input [1031:0] padded_data;
input [10:0]   total_bits;

output reg in_phase, quadrature, valid_out;

reg [10:0] bit_count;
reg        running;          // FIX 6: "I am streaming" is NOT "my output is valid"

always @(posedge clk) begin
    if (reset) begin
        in_phase <= 1'b0; quadrature <= 1'b0;   
        valid_out <= 1'b0; running <= 1'b0; bit_count <= 0;
    end
    else if (start_demux) begin
        bit_count <= 0;  running <= 1'b1;  valid_out <= 1'b0;
    end
    else if (running) begin
        in_phase   <= padded_data[bit_count];
        quadrature <= padded_data[bit_count + 1];
        valid_out  <= 1'b1;                    
        if (bit_count == total_bits - 2) begin   
            running   <= 1'b0;
            bit_count <= 0;
        end
        else bit_count <= bit_count + 2;
    end
    else valid_out <= 1'b0;
end

endmodule