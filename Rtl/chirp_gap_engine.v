module chirp_gap_engine #(
    parameter TSUB             = 38,    // samples per subchirp (spec 6.5a.4.3, Tsub)
    parameter NSUB              = 4,     // subchirps per chirp sequence
    parameter TEVEN             = 10,    // Table 42, chirp index m=1
    parameter TODD              = 70,    // Table 42, chirp index m=1
    parameter PHASE_FIFO_DEPTH  = 4096,  // >= max symbols for a 127-byte PSDU (2848)
    parameter PFP_AW            = 12,    // $clog2(PHASE_FIFO_DEPTH)
    parameter SYM_CNT_W         = 12     // width for total_symbols / symbols_consumed
)(
    input  wire                     clk,
    input  wire                     reset,
    input  wire                     pkt_start,      // tx_start: (re)initialize for a new transmission
    input  wire                     phase_valid_in, // dqpsk_out_valid
    input  wire [2:0]               phase_in,       // dqpsk_out_phase (always odd: 1,3,5,7)
    input  wire [SYM_CNT_W-1:0]     total_symbols,  // total DQPSK symbols expected this packet (always a multiple of 4)

    output wire                     sample_valid,   // one pulse per OUTPUT SAMPLE (chip rate) -> dqcsk_modulator.valid_in
    output wire [2:0]               sample_phase,   // held DQPSK phase for this sample -> dqcsk_modulator.sn_phase
    output wire signed [5:0]        sample_csk_real,// gated chirp value (0 during gap) -> dqcsk_modulator.csk_real
    output wire signed [5:0]        sample_csk_imag,
    output reg                      all_done        // pulses 1 cycle once the last group's gap has completed
);

    // ---------------------------------------------------------------------
    // Phase FIFO: buffers DQPSK symbols as they arrive (fast, front end)
    // until this engine is ready to consume them (slow, chip rate).
    // ---------------------------------------------------------------------
    reg  [2:0]        fifo_mem [0:PHASE_FIFO_DEPTH-1];
    reg  [PFP_AW-1:0] wr_ptr, rd_ptr;
    reg  [PFP_AW:0]   fifo_count;

    wire fifo_full  = (fifo_count == PHASE_FIFO_DEPTH);
    wire fifo_empty = (fifo_count == 0);
    wire push       = phase_valid_in && !fifo_full;
    wire [2:0] fifo_rd_data = fifo_mem[rd_ptr];

   
    always @(posedge clk) begin
        if (!reset && phase_valid_in && fifo_full)
            $display("%0t: WARNING chirp_gap_engine: phase FIFO overflow,)", $time);
    end
    // synthesis translate_on

    // ---------------------------------------------------------------------
    // Main chip-rate FSM
    // ---------------------------------------------------------------------
    localparam ACTIVE = 2'd0,
               GAP    = 2'd1,
               DONE   = 2'd2;

    reg [1:0]            state;
    reg [5:0]             sample_cnt;       // 0..TSUB-1 within the current subchirp
    reg [1:0]             subchirp_cnt;     // 0..NSUB-1 within the current chirp sequence
    reg [SYM_CNT_W-1:0]   symbols_consumed;
    reg                   group_parity;     // 0 = even group (Teven), 1 = odd group (Todd)
    reg [9:0]             gap_cnt;
    reg [2:0]             held_phase;

    wire need_new_phase = (state == ACTIVE) && (sample_cnt == 6'd0);
    wire stall          = need_new_phase && fifo_empty;   // front end hasn't produced this symbol yet
    wire pop            = need_new_phase && !fifo_empty;

    wire [9:0] gap_len = group_parity ? TODD[9:0] : TEVEN[9:0];

    wire [7:0] rom_addr = subchirp_cnt * TSUB + sample_cnt; // 0..151, meaningful only in ACTIVE && !stall
    wire [5:0] rom_real, rom_imag;

    CSK_ROM #(.NUM_SAMPLES(152)) u_chirp_rom (
        .address  (rom_addr),
        .imag_out (rom_imag),
        .real_out (rom_real)
    );

    assign sample_valid    = (state == ACTIVE && !stall) || (state == GAP);
    assign sample_phase    = (state == ACTIVE && sample_cnt == 6'd0) ? fifo_rd_data : held_phase;
    assign sample_csk_real = (state == ACTIVE && !stall) ? rom_real : 6'sd0;
    assign sample_csk_imag = (state == ACTIVE && !stall) ? rom_imag : 6'sd0;

    // ---- phase FIFO pointers / occupancy ----
    integer p;
    always @(posedge clk ) begin
        if (reset) begin
            wr_ptr     <= {PFP_AW{1'b0}};
            rd_ptr     <= {PFP_AW{1'b0}};
            fifo_count <= {(PFP_AW+1){1'b0}};
        end else if (pkt_start) begin
            wr_ptr     <= {PFP_AW{1'b0}};
            rd_ptr     <= {PFP_AW{1'b0}};
            fifo_count <= {(PFP_AW+1){1'b0}};
        end else begin
            if (push) begin
                fifo_mem[wr_ptr] <= phase_in;
                wr_ptr           <= wr_ptr + 1'b1;
            end
            if (pop)
                rd_ptr <= rd_ptr + 1'b1;

            case ({push, pop})
                2'b10:   fifo_count <= fifo_count + 1'b1;
                2'b01:   fifo_count <= fifo_count - 1'b1;
                default: fifo_count <= fifo_count; // 00, or 11 (push+pop cancel out)
            endcase
        end
    end

    // ---- chip-rate state machine ----
    always @(posedge clk ) begin
        if (reset) begin
            state            <= ACTIVE;
            sample_cnt       <= 6'd0;
            subchirp_cnt     <= 2'd0;
            symbols_consumed <= {SYM_CNT_W{1'b0}};
            group_parity     <= 1'b0;
            gap_cnt          <= 10'd0;
            held_phase       <= 3'd0;
            all_done         <= 1'b0;
        end else if (pkt_start) begin
            state            <= ACTIVE;
            sample_cnt       <= 6'd0;
            subchirp_cnt     <= 2'd0;
            symbols_consumed <= {SYM_CNT_W{1'b0}};
            group_parity     <= 1'b0;
            gap_cnt          <= 10'd0;
            all_done         <= 1'b0;
        end else begin
            all_done <= 1'b0; // default; pulsed below when true

            if (pop)
                held_phase <= fifo_rd_data;

            case (state)
                ACTIVE: begin
                    if (!stall) begin
                        if (sample_cnt == TSUB - 1) begin
                            sample_cnt <= 6'd0;
                            if (subchirp_cnt == NSUB - 1) begin
                                subchirp_cnt     <= 2'd0;
                                symbols_consumed <= symbols_consumed + 1'b1;
                                gap_cnt          <= 10'd0;
                                state            <= GAP;
                            end else begin
                                subchirp_cnt     <= subchirp_cnt + 1'b1;
                                symbols_consumed <= symbols_consumed + 1'b1;
                            end
                        end else begin
                            sample_cnt <= sample_cnt + 1'b1;
                        end
                    end
                    // stall: hold everything, wait for the phase FIFO
                end

                GAP: begin
                    if (gap_cnt == gap_len - 1'b1) begin
                        gap_cnt      <= 10'd0;
                        group_parity <= ~group_parity;
                        if (symbols_consumed == total_symbols) begin
                            state    <= DONE;
                            all_done <= 1'b1;
                        end else begin
                            state <= ACTIVE;
                        end
                    end else begin
                        gap_cnt <= gap_cnt + 1'b1;
                    end
                end

                DONE: begin
                    // idle until the next pkt_start
                end

                default: state <= ACTIVE;
            endcase
        end
    end

endmodule
