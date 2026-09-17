module dmux_2_mapper (
    input  wire       clk,
    input  wire       reset,        
    input  wire       valid_in,     
    input  wire       bit_in,       // 1-bit serial input from Demux
    output reg        valid_out,   
    output reg  [5:0] symbol_out    // 6-bit symbol output  for Symbol Mapper
);

    reg [5:0] shift_reg;
    reg [2:0] bit_cnt;

    always @(posedge clk) begin
        if (reset) begin
            shift_reg  <= 6'd0;
            bit_cnt    <= 3'd0;
            symbol_out <= 6'd0;
            valid_out  <= 1'b0;
        end else begin
            valid_out <= 1'b0; // Default 

            if (valid_in) begin
                // Store incoming bit (b0 arrives first at index 0, b5 arrives last at index 5)
                shift_reg[bit_cnt] <= bit_in;

                if (bit_cnt == 3'd5) begin
                    bit_cnt    <= 3'd0;
                    // Output full 6-bit symbol: b5 is bit_in, b4..b0 are stored in shift_reg
                    symbol_out <= {shift_reg[0], shift_reg[1], shift_reg[2], shift_reg[3], shift_reg[4], bit_in};
                    valid_out  <= 1'b1;
                end else begin
                    bit_cnt <= bit_cnt + 1'b1;
                end
            end
        end
    end

endmodule