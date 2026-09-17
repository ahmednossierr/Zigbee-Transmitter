module css_phy_transmitter (
    input  wire        clk,
    input  wire        reset,
    input  wire        start_Tx,
    input  wire [7:0]  payloadLength,
    output wire        done_Tx,
    output wire [7:0]  Tx_real,
    output wire [7:0]  Tx_imag
);

//Ram interfaces and instant 
wire [7:0]     ram_dout;
wire [1015:0]  psdu_out;
ram u_ram (
        .clk          (clk),
        .reset        (reset),
        .write_enable (1'b0),
        .read_enable  (1'b0),
        .addr         (7'd0),
        .din          (8'd0),
        .dout         (ram_dout),
        .psdu_out     (psdu_out)
    );
/* This is commented because my testbencg instialize it already
initial begin
    $readmemh("D:/ITI_Summer_2026/ITI Summer Project/Final_Submission/Codes/Scripts/ram_random_data.txt", u_ram.mem);
end
*/
// Zero Padding interfaces and instant
wire zp_out_bit;
wire padding_valid;
wire padding_done;
wire [1031:0]  padded_data;
wire [10:0]   total_bits;

zero_padding #(.Data_Rate(250)) u_zero_padding (
        .clk           (clk),
        .reset         (reset),
        .start_tx      (start_Tx),
        .payload_length(payloadLength),
        .PSDU          (psdu_out),
        .out_bit       (zp_out_bit),
        .valid_out     (padding_valid),
        .padding_done  (padding_done),
        .padded_data   (padded_data),
        .total_bits    (total_bits)
    );



// Demux (Even/Odd bits) interfaces and instant
wire in_phase;
wire quadrature;
wire demux_valid_out;

demux u_demux (
        .clk         (clk),
        .reset       (reset),
        .start_demux (padding_done),
        .padded_data (padded_data),
        .total_bits  (total_bits),
        .in_phase    (in_phase),
        .quadrature  (quadrature),
        .valid_out   (demux_valid_out)
    );



// Serial-to-parallel (I and Q paths) interfaces and instant
wire [5:0] i_symbol, q_symbol;
wire  i_symbol_valid, q_symbol_valid;

dmux_2_mapper u_i_dmux_2_mapper (
        .clk        (clk),
        .reset      (reset),
        .valid_in   (demux_valid_out),
        .bit_in     (in_phase),
        .valid_out  (i_symbol_valid),
        .symbol_out (i_symbol)
    );

dmux_2_mapper u_q_dmux_2_mapper (
        .clk        (clk),
        .reset      (reset),
        .valid_in   (demux_valid_out),
        .bit_in     (quadrature),
        .valid_out  (q_symbol_valid),
        .symbol_out (q_symbol)
    );



 // Symbol Mapper (I and Q paths) interfaces and instant

wire [31:0] i_symbol_mapper_out, q_symbol_mapper_out;
wire   i_symbol_mapper_valid, q_symbol_mapper_valid;

symbol_mapper u_i_symbol_mapper (
        .clk        (clk),
        .reset      (reset),
        .valid_in   (i_symbol_valid),
        .data_in    (i_symbol),
        .data_out   (i_symbol_mapper_out),
        .valid_out  (i_symbol_mapper_valid)
    );

symbol_mapper u_q_symbol_mapper (
        .clk        (clk),
        .reset      (reset),
        .valid_in   (q_symbol_valid),
        .data_in    (q_symbol),
        .data_out   (q_symbol_mapper_out),
        .valid_out  (q_symbol_mapper_valid)
    );



// Symbol Buffer to Interleaver (I and Q paths) interfaces and instant

wire [63:0] i_buffer_out, q_buffer_out;
wire  i_buffer_valid, q_buffer_valid;
wire [63:0] i_interleaver_out, q_interleaver_out;

symbol_buffer u_i_symbol_buffer (
        .clk          (clk),
        .reset        (reset),
        .sym_valid    (i_symbol_mapper_valid),
        .sym_data     (i_symbol_mapper_out),
        .intrlv_valid (i_buffer_valid),
        .intrlv_data  (i_buffer_out)
    );

symbol_buffer u_q_symbol_buffer (
        .clk          (clk),
        .reset        (reset),
        .sym_valid    (q_symbol_mapper_valid),
        .sym_data     (q_symbol_mapper_out),
        .intrlv_valid (q_buffer_valid),
        .intrlv_data  (q_buffer_out)
    );

interleaver_250kbps u_i_interleaver (
        .block_in  (i_buffer_out),
        .block_out (i_interleaver_out)
    );

interleaver_250kbps u_q_interleaver (
        .block_in  (q_buffer_out),
        .block_out (q_interleaver_out)
    );


// Block-ready controller: pulses tx_start once BOTH I and Q paths have
wire tx_start;
block_ready_ctrl u_block_ready_ctrl (
        .clk           (clk),
        .reset         (reset),
        .start_tx      (start_Tx),
        .padding_done  (padding_done),
        .total_bits    (total_bits),
        .i_block_valid (i_buffer_valid),
        .q_block_valid (q_buffer_valid),
        .tx_start      (tx_start)
    );



// Form PPDU interfaces and instant
wire ppdu_i_out, ppdu_q_out, ppdu_valid, ppdu_done;

PPDU u_ppdu (
        .clk          (clk),
        .reset        (reset),
        .start        (tx_start),
        .total_bits   (total_bits),
        .i_path_data  (i_interleaver_out),
        .q_path_data  (q_interleaver_out),
        .i_path_valid (i_buffer_valid),
        .q_path_valid (q_buffer_valid),
        .ppdu_i_out   (ppdu_i_out),
        .ppdu_q_out   (ppdu_q_out),
        .ppdu_valid   (ppdu_valid),
        .done         (ppdu_done)
    );

// QPSK Mapper
wire signed [1:0] xn_real, xn_imag;
 wire              qpsk_valid_out;

qpsk_mapper u_qpsk_mapper (
        .clk        (clk),
        .reset      (reset),
        .inphase    (ppdu_i_out),
        .quadrature (ppdu_q_out),
        .valid_in   (ppdu_valid),
        .xn_real    (xn_real),
        .xn_imag    (xn_imag),
        .valid_out  (qpsk_valid_out)
    );



// DQPSK Coding
wire   dqpsk_out_valid;
wire [2:0] dqpsk_out_phase;

    dqpsk_encoder u_dqpsk_encoder (
        .clk       (clk),
        .reset     (reset),
        .pkt_start (tx_start),
        .valid_in  (qpsk_valid_out),
        .xn_real   (xn_real),
        .xn_imag   (xn_imag),
        .out_valid (dqpsk_out_valid),
        .out_phase (dqpsk_out_phase)
    );


// ---------------------------------------------------------------------
// Chirp/gap chip-rate engine (spec 6.5a.4 subchirp hold + Table 42 gap
// timing -- see chirp_gap_engine.v for the full design rationale).
// Replaces the old free-running CSK_generator + a hand-tuned 2-cycle
// reset delay: chirp_gap_engine's own phase-FIFO "stall" naturally waits
// for the first real DQPSK symbol instead of assuming a fixed latency.
// ---------------------------------------------------------------------
localparam PRE_PLUS_SFD  = 12'd96; // 80 (preamble) + 16 (SFD), same as PPDU.v
localparam SYM_CNT_W     = 12;

reg  [SYM_CNT_W-1:0] total_symbols;
reg                  total_symbols_valid;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        total_symbols       <= {SYM_CNT_W{1'b0}};
        total_symbols_valid <= 1'b0;
    end else if (start_Tx) begin
        total_symbols_valid <= 1'b0;
    end else if (padding_done) begin
        total_symbols       <= PRE_PLUS_SFD + (total_bits / 24) * 64;
        total_symbols_valid <= 1'b1;
    end
end

wire                sample_valid;
wire [2:0]          sample_phase;
wire signed [5:0]   sample_csk_real, sample_csk_imag;
wire                engine_all_done;

chirp_gap_engine #(
        .SYM_CNT_W (SYM_CNT_W)
    ) u_chirp_gap_engine (
        .clk             (clk),
        .reset            (reset),
        .pkt_start        (tx_start),
        .phase_valid_in   (dqpsk_out_valid),
        .phase_in         (dqpsk_out_phase),
        .total_symbols    (total_symbols),
        .sample_valid     (sample_valid),
        .sample_phase     (sample_phase),
        .sample_csk_real  (sample_csk_real),
        .sample_csk_imag  (sample_csk_imag),
        .all_done         (engine_all_done)
    );

// Final Modulator that produces the Tx_real / Tx_imag
wire tx_valid;

dqcsk_modulator u_dqcsk_modulator (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (sample_valid),
        .sn_phase  (sample_phase),
        .csk_real  (sample_csk_real),
        .csk_imag  (sample_csk_imag),
        .valid_out (tx_valid),
        .tx_real   (Tx_real),
        .tx_imag   (Tx_imag)
    );

reg done_Tx_r;

always @(posedge clk or posedge reset) begin
    if (reset)
        done_Tx_r <= 1'b0;
    else if (start_Tx)
        done_Tx_r <= 1'b0;
    else if (engine_all_done)
        done_Tx_r <= 1'b1;
end

assign done_Tx = done_Tx_r;

endmodule