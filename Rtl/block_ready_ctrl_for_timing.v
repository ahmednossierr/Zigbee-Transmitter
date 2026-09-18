module block_ready_ctrl (
    input  wire       clk,
    input  wire       reset,
    input  wire       start_tx,      
    input  wire       padding_done,  // pulses once total_bits becomes valid
    input  wire [10:0] total_bits,
    input  wire       i_block_valid, 
    input  wire       q_block_valid, /
    output reg        tx_start       // pulses exactly once, when BOTH paths have delivered
                                     
                                      
                                      
);

    reg [7:0] i_blk_cnt, q_blk_cnt;
    reg [7:0] total_blocks;
    reg       fired;

  
    wire [7:0] i_next = i_blk_cnt + i_block_valid;
    wire [7:0] q_next = q_blk_cnt + q_block_valid;
    wire       all_ready = (total_blocks != 0) &&
                            (i_next >= total_blocks) &&
                            (q_next >= total_blocks);

    always @(posedge clk ) begin
        if (reset) begin
            i_blk_cnt    <= 8'd0;
            q_blk_cnt    <= 8'd0;
            total_blocks <= 8'd0;
            fired        <= 1'b0;
            tx_start     <= 1'b0;
        end else begin
            tx_start <= 1'b0;

            if (start_tx) begin
                // fresh packet: clear counts and re-arm
                i_blk_cnt    <= 8'd0;
                q_blk_cnt    <= 8'd0;
                total_blocks <= 8'd0;
                fired        <= 1'b0;
            end else begin
                if (padding_done)
                    total_blocks <= total_bits / 24;

                i_blk_cnt <= i_next;
                q_blk_cnt <= q_next;

                if (all_ready && !fired) begin
                    tx_start <= 1'b1;
                    fired    <= 1'b1;
                end
            end
        end
    end

endmodule
