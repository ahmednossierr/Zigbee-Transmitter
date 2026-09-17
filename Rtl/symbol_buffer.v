module symbol_buffer (
    input  wire        clk,
    input  wire        reset,
    input  wire        sym_valid,    // High when the Symbol Mapper has a valid 32-bit output
    input  wire [31:0] sym_data,     // 32-bit codeword from the Symbol Mapper
    output reg         intrlv_valid, // High when a full 64-bit block is ready
    output reg  [63:0] intrlv_data   // 64-bit concatenated block for the Interleaver
);

    reg        toggle;
    reg [31:0] sym_buffer;

    always @(posedge clk ) begin
        if (reset) begin
            toggle       <= 1'b0;
            sym_buffer   <= 32'd0;
            intrlv_valid <= 1'b0;
            intrlv_data  <= 64'd0;
        end else begin

            intrlv_valid <= 1'b0;       // Default 

            if (sym_valid) begin
                if (toggle == 1'b0) begin
                    // Step 1: Capture the first 32-bit codeword (Even symbol)
                    sym_buffer <= sym_data;
                    toggle     <= 1'b1;
                end else begin
                    // Step 2: Receive the second 32-bit codeword (Odd symbol)
                    // Combine the buffered even symbol with the live odd symbol
                   intrlv_data <= {sym_buffer, sym_data};   
                    intrlv_valid <= 1'b1;
                    toggle       <= 1'b0;    // Reset the toggle to prepare for the next pair
                end
            end
        end
    end

endmodule