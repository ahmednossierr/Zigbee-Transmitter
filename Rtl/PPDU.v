module PPDU (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [10:0] total_bits,

    input wire [63:0] i_path_data,
    input wire [63:0] q_path_data,
    input wire i_path_valid,
    input wire q_path_valid,

    output reg ppdu_i_out,
    output reg ppdu_q_out,
    output reg ppdu_valid,
    output reg done
);

    localparam IDLE       = 3'd0,
               PREAMBLE   = 3'd1,
               SFD        = 3'd2,
               WAIT       = 3'd3,
               SEND       = 3'd4,
               DONE_STATE = 3'd5;

    localparam PRE_LEN    = 80;
    localparam PRE_VAL    = 1'b1;
    localparam SFD_LEN    = 16;
    // FIFO_DEPTH was 8, sized for small payloads only. The front end
    // (RAM..symbol_buffer) produces a new 64-bit I/Q block every few
    // cycles with no back-pressure, while this FSM only drains one block
    // every 64 (SEND) + 1 (WAIT) cycles. For payloads needing more than 8
    // blocks in flight (>= 55 bytes here), the old depth silently dropped
    // blocks (confirmed by the "FIFO overflow, incoming block dropped"
    // warning firing for len=55/125). 64 comfortably covers the IEEE
    // 802.15.4a spec's 127-byte max PSDU (total_bits/24 maxes out at 43
    // blocks there), so the front end can run to completion and simply
    // queue up without ever overflowing.
    localparam FIFO_DEPTH = 64;
    localparam FIFO_AW    = 6; // $clog2(FIFO_DEPTH)

    reg sfd_rom [0:SFD_LEN-1];

    initial begin
        sfd_rom[0]=0;  sfd_rom[1]=1;  sfd_rom[2]=1;  sfd_rom[3]=1;
        sfd_rom[4]=1;  sfd_rom[5]=0;  sfd_rom[6]=1;  sfd_rom[7]=0;
        sfd_rom[8]=0;  sfd_rom[9]=0;  sfd_rom[10]=1; sfd_rom[11]=0;
        sfd_rom[12]=0; sfd_rom[13]=0; sfd_rom[14]=1; sfd_rom[15]=1;
    end

    reg [2:0] state;
    reg [6:0] symbol_index;
    reg [63:0] i_shift_reg;
    reg [63:0] q_shift_reg;

    // FIFO / Buffer for incoming blocks (depth = FIFO_DEPTH)
    reg [63:0] fifo_i [0:FIFO_DEPTH-1];
    reg [63:0] fifo_q [0:FIFO_DEPTH-1];
    reg [FIFO_AW-1:0] fifo_head;
    reg [FIFO_AW-1:0] fifo_tail;
    reg [FIFO_AW:0]   fifo_count;

    reg [7:0]  blocks_sent_count;
    wire [7:0] total_blocks;

    assign total_blocks = total_bits / 24;

    // ------------------------------------------------------------------
    // FIX 1 (the hang): push and pop are decided ONCE, combinationally,
    // and fifo_count is updated from a single case statement below.
    // The original code had two separate non-blocking assignments to
    // fifo_count (one in the unconditional push block, one inside the
    // WAIT branch). If both fired on the same clock edge, only the
    // textually-last one took effect and the other's contribution to
    // fifo_count was silently lost -- fifo_head/fifo_tail stayed correct
    // but fifo_count under-counted, and WAIT would then wait forever on
    // "fifo_count > 0" for data that was actually already sitting in
    // the array. That is the exact failure mode reproduced during
    // debugging (fifo_head=2, fifo_tail=3, fifo_count=0 -> stuck).
    // ------------------------------------------------------------------
    wire fifo_full     = (fifo_count == FIFO_DEPTH);
    wire pop_req       = (state == WAIT) && (fifo_count > 0);
    wire push_req_raw  = i_path_valid && q_path_valid;
    // A push landing on the same cycle as a pop is fine (net count is
    // unchanged, there's room because a slot is being freed). A push
    // that arrives while genuinely full, with no pop to free a slot,
    // is dropped instead of silently overwriting an unread entry.
    wire push_req      = push_req_raw && !(fifo_full && !pop_req);

    // ------------------------------------------------------------------
    // FIX 2 (visibility, not a functional change): the design assumes
    // i_path_valid and q_path_valid always strobe on the exact same
    // clock edge. That assumption lives outside this module (in the
    // two symbol_buffer instances feeding it). If it's ever violated,
    // a whole block silently disappears with no error. These checks
    // turn that into a visible simulation message instead of a silent
    // hang, and are stripped for synthesis.
    // ------------------------------------------------------------------
    // synthesis translate_off
    always @(posedge clk) begin
        if (!reset && (i_path_valid !== q_path_valid))
            $display("%0t: WARNING PPDU: i_path_valid(%b) != q_path_valid(%b) -- a block will be dropped",
                      $time, i_path_valid, q_path_valid);
        if (!reset && push_req_raw && fifo_full && !pop_req)
            $display("%0t: WARNING PPDU: FIFO overflow, incoming block dropped (fifo_count=%0d)",
                      $time, fifo_count);
    end
    // synthesis translate_on

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state             <= IDLE;
            ppdu_valid        <= 1'b0;
            done              <= 1'b0;
            i_shift_reg       <= 64'b0;
            q_shift_reg       <= 64'b0;
            symbol_index      <= 7'd0;
            ppdu_i_out        <= 1'b0;
            ppdu_q_out        <= 1'b0;
            fifo_head         <= {FIFO_AW{1'b0}};
            fifo_tail         <= {FIFO_AW{1'b0}};
            fifo_count        <= {(FIFO_AW+1){1'b0}};
            blocks_sent_count <= 8'd0;
        end else begin
            done <= 1'b0;

            // ---- FIFO write side: only writes data / advances tail on an accepted push ----
            if (push_req) begin
                fifo_i[fifo_tail] <= i_path_data;
                fifo_q[fifo_tail] <= q_path_data;
                fifo_tail         <= fifo_tail + 1'b1;
            end

            // ---- FIFO occupancy: the single place that decides fifo_count ----
            case ({push_req, pop_req})
                2'b10:   fifo_count <= fifo_count + 1'b1;
                2'b01:   fifo_count <= fifo_count - 1'b1;
                default: fifo_count <= fifo_count; // 00, or 11 (push+pop cancel out)
            endcase

            case (state)
            IDLE: begin
                ppdu_valid        <= 1'b0;
                // NOTE: fifo_head/fifo_tail/fifo_count are deliberately NOT
                // cleared here. They're only cleared on a real `reset`.
                // Real blocks can legitimately arrive (and get pushed by
                // the push_req logic above) while PPDU is still sitting in
                // IDLE waiting for `start` -- clearing them here every
                // cycle would silently discard that data, including the
                // very block that arrives on the same cycle `start` fires.
                // By the time a transmission legitimately finishes
                // (DONE_STATE), all pushed blocks have already been
                // popped, so fifo_count is naturally back to 0 anyway.
                blocks_sent_count <= 8'd0;
                if (start) begin
                    symbol_index <= 7'd0;
                    ppdu_i_out   <= PRE_VAL;
                    ppdu_q_out   <= PRE_VAL;
                    ppdu_valid   <= 1'b1;
                    state        <= PREAMBLE;
                end
            end

            PREAMBLE: begin
                ppdu_i_out <= PRE_VAL;
                ppdu_q_out <= PRE_VAL;
                if (symbol_index == PRE_LEN - 1) begin
                    symbol_index <= 7'd0;
                    ppdu_i_out   <= sfd_rom[0];
                    ppdu_q_out   <= sfd_rom[0];
                    state        <= SFD;
                end else begin
                    symbol_index <= symbol_index + 1;
                end
            end

            SFD: begin
                if (symbol_index == SFD_LEN - 1) begin
                    ppdu_valid <= 1'b0;
                    state      <= WAIT;
                end else begin
                    symbol_index <= symbol_index + 1;
                    ppdu_i_out   <= sfd_rom[symbol_index + 1];
                    ppdu_q_out   <= sfd_rom[symbol_index + 1];
                end
            end

                WAIT: begin
                ppdu_valid <= 1'b0;
                if (pop_req) begin
                    i_shift_reg <= fifo_i[fifo_head];
                    q_shift_reg <= fifo_q[fifo_head];
                    fifo_head   <= fifo_head + 1'b1;

                    symbol_index <= 7'd0;
                    state        <= SEND; 
                end
            end

            SEND: begin

                ppdu_valid <= 1'b1;
                ppdu_i_out <= i_shift_reg[63];
                ppdu_q_out <= q_shift_reg[63];

                if (symbol_index == 7'd63) begin
                    symbol_index      <= 7'd0;
                    blocks_sent_count <= blocks_sent_count + 1'b1;

                    if (blocks_sent_count + 1'b1 >= total_blocks) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= WAIT;
                    end
                end else begin
                    symbol_index <= symbol_index + 1;
                    i_shift_reg  <= i_shift_reg << 1;
                    q_shift_reg  <= q_shift_reg << 1;
                end
            end
            DONE_STATE: begin
                ppdu_valid <= 1'b0;
                done       <= 1'b1;
                state      <= IDLE;
            end

            default: state <= IDLE;

            endcase
        end
    end
endmodule