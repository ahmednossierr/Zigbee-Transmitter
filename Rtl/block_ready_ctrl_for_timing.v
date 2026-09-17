module block_ready_ctrl (
    input  wire       clk,
    input  wire       reset,
    input  wire       start_tx,      // pulses once to kick off a new packet's processing
    input  wire       padding_done,  // pulses once total_bits becomes valid
    input  wire [10:0] total_bits,
    input  wire       i_block_valid, // pulses once per completed I block (symbol_buffer+interleaver)
    input  wire       q_block_valid, // pulses once per completed Q block
    output reg        tx_start       // pulses exactly once, when BOTH paths have delivered
                                      // their last block -- this is what should drive
                                      // PPDU.start / dqpsk_encoder.pkt_start instead of
                                      // start_tx, to get non-pipelined operation
);

    reg [7:0] i_blk_cnt, q_blk_cnt;
    reg [7:0] total_blocks;
    reg       fired;

    // include this cycle's increment(s) so the comparison fires on the exact
    // cycle the last block arrives, not one cycle late
    wire [7:0] i_next = i_blk_cnt + i_block_valid;
    wire [7:0] q_next = q_blk_cnt + q_block_valid;
    wire       all_ready = (total_blocks != 0) &&
                            (i_next >= total_blocks) &&
                            (q_next >= total_blocks);

    always @(posedge clk or posedge reset) begin
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