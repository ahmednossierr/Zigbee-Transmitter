module css_each_block_tb();

//Define Inputs
reg clk;
reg reset;
reg start_tx; // Triggers Zero Padding
reg [7:0] payload_length;
reg csk_rst_tb; // Testbench controlled reset for the CSK Generator


//Define Outputs
wire [7:0] tx_real;
wire [7:0] tx_imag;


// Ram interfaces and instant 
reg   write_enable;  
reg   read_enable; 
reg   [6:0] addr;  
reg   [7:0] din;
wire  [7:0] dout ;
wire [1015:0] psdu_out;

ram DUT_RAM (
    .clk          (clk),
    .reset        (reset),
    .write_enable (write_enable),
    .read_enable  (read_enable),
    .addr         (addr),
    .din          (din),
    .dout         (dout),
    .psdu_out     (psdu_out)
);


// Zero Padding interfaces and instant 
wire out_bit;
wire padding_valid;
wire padding_done;
wire [1031:0] padded_data;
wire [10:0] total_bits;

zero_padding #(.Data_Rate(250)) DUT_ZERO_PADDING (
    .clk          (clk),
    .reset        (reset),
    .start_tx     (start_tx),
    .payload_length(payload_length),
    .PSDU         (psdu_out),
    .out_bit      (out_bit),
    .valid_out    (padding_valid),
    .padding_done (padding_done),
    .padded_data  (padded_data),
    .total_bits   (total_bits)
);


// Demux interfaces and instant 
wire in_phase;
wire quadrature;
wire demux_valid_out;

demux DUT_DEMUX (
    .clk          (clk),
    .reset        (reset),
    .start_demux  (padding_done), // Daisy-chained
    .padded_data  (padded_data),
    .total_bits   (total_bits),
    .in_phase     (in_phase),
    .quadrature   (quadrature),
    .valid_out    (demux_valid_out)
);


// I-Path DMUX_2_MAPPER interfaces and instant 
wire [5:0] i_symbol;
wire i_symbol_valid;

dmux_2_mapper DUT_I_DMUX_2_MAPPER (
    .clk        (clk),
    .reset      (reset),
    .valid_in   (demux_valid_out), // Daisy-chained
    .bit_in     (in_phase),
    .valid_out  (i_symbol_valid),
    .symbol_out (i_symbol)
);


// Q-Path DMUX_2_MAPPER interfaces and instant 
wire [5:0] q_symbol;
wire q_symbol_valid;

dmux_2_mapper DUT_Q_DMUX_2_MAPPER (
    .clk        (clk),
    .reset      (reset),
    .valid_in   (demux_valid_out), // Daisy-chained
    .bit_in     (quadrature),
    .valid_out  (q_symbol_valid),
    .symbol_out (q_symbol)
);


// I-Path Symbol Mapper interfaces and instant 
wire [31:0] i_symbol_mapper_out;
wire i_symbol_mapper_valid;

symbol_mapper DUT_I_SYMBOL_MAPPER (
    .clk        (clk),
    .reset      (reset),
    .valid_in   (i_symbol_valid), // Daisy-chained
    .data_in    (i_symbol),
    .data_out   (i_symbol_mapper_out),
    .valid_out  (i_symbol_mapper_valid)
);


// Q-Path Symbol Mapper interfaces and instant 
wire [31:0] q_symbol_mapper_out;
wire q_symbol_mapper_valid;

symbol_mapper DUT_Q_SYMBOL_MAPPER (
    .clk        (clk),
    .reset      (reset),
    .valid_in   (q_symbol_valid), // Daisy-chained
    .data_in    (q_symbol),
    .data_out   (q_symbol_mapper_out),
    .valid_out  (q_symbol_mapper_valid)
);


// I-Path Symbol Buffer interfaces and instant 
wire [63:0] i_buffer_out;
wire i_buffer_valid;

symbol_buffer DUT_I_SYMBOL_BUFFER (
    .clk          (clk),
    .reset        (reset),
    .sym_valid    (i_symbol_mapper_valid), // Daisy-chained
    .sym_data     (i_symbol_mapper_out),
    .intrlv_valid (i_buffer_valid),
    .intrlv_data  (i_buffer_out)
);


// Q-Path Symbol Buffer interfaces and instant 
wire [63:0] q_buffer_out;
wire q_buffer_valid;

symbol_buffer DUT_Q_SYMBOL_BUFFER (
    .clk          (clk),
    .reset        (reset),
    .sym_valid    (q_symbol_mapper_valid), // Daisy-chained
    .sym_data     (q_symbol_mapper_out),
    .intrlv_valid (q_buffer_valid),
    .intrlv_data  (q_buffer_out)
);


// I-Path Interleaver interfaces and instant 
wire [63:0] i_interleaver_out;
interleaver_250kbps DUT_I_INTERLEAVER (
    .block_in  (i_buffer_out),
    .block_out (i_interleaver_out)
);

// Q-Path Interleaver interfaces and instant 
wire [63:0] q_interleaver_out;
interleaver_250kbps DUT_Q_INTERLEAVER (
    .block_in  (q_buffer_out),
    .block_out (q_interleaver_out)
);


wire tx_start;
block_ready_ctrl DUT_BLOCK_READY_CTRL (
    .clk            (clk),
    .reset          (reset),
    .start_tx       (start_tx),
    .padding_done   (padding_done),
    .total_bits     (total_bits),
    .i_block_valid  (i_buffer_valid),
    .q_block_valid  (q_buffer_valid),
    .tx_start       (tx_start)
);


// Form PPDU interfaces and instant 
wire ppdu_i_out;
wire ppdu_q_out;
wire ppdu_valid;
wire ppdu_done;

PPDU DUT_FORM_PPDU (
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


// QPSK Mapper interfaces and instant
wire signed [1:0] xn_real;
wire signed [1:0] xn_imag;
wire qpsk_valid_out;

qpsk_mapper DUT_QPSK_MAPPER (
    .clk        (clk),
    .reset      (reset),
    .inphase    (ppdu_i_out),
    .quadrature (ppdu_q_out),
    .valid_in   (ppdu_valid), 
    .xn_real    (xn_real),
    .xn_imag    (xn_imag),
    .valid_out  (qpsk_valid_out)
);


// DQPSK Encoder interfaces and instant
wire dqpsk_out_valid;
wire [2:0] dqpsk_out_phase;

dqpsk_encoder DUT_DQPSK_ENCODER (
    .clk       (clk),
    .reset     (reset),
    .pkt_start (tx_start),     // Aligned with PPDU
    .valid_in  (qpsk_valid_out), 
    .xn_real   (xn_real),
    .xn_imag   (xn_imag),
    .out_valid (dqpsk_out_valid),
    .out_phase (dqpsk_out_phase)
);


// CSK Generator interfaces and instant
wire [5:0] csk_real_out;
wire [5:0] csk_imag_out;

CSK_generator DUT_CSK_GENERATOR (
    .clk       (clk),
    .CSK_rst   (reset | csk_rst_tb), // Controlled by testbench logic to align perfectly
    .imag_out  (csk_imag_out),
    .real_out  (csk_real_out)
);



wire tx_valid;
dqcsk_modulator DUT_DQCSK_MODULATOR (
    .clk       (clk),
    .reset     (reset),
    .valid_in  (dqpsk_out_valid),
    .sn_phase  (dqpsk_out_phase),
    .csk_real  (csk_real_out),
    .csk_imag  (csk_imag_out),
    .valid_out (tx_valid),
    .tx_real   (tx_real),
    .tx_imag   (tx_imag)
);


//Generation of clock
initial begin
    clk = 0;
    forever begin
        #5 clk = ~clk;
    end
end


// Read memory
initial begin
    $readmemh("D:/ITI_Summer_2026/ITI Summer Project/Final_Submission/Codes/Scripts/ram_random_data.txt", DUT_RAM.mem);
end


// Reset task
task reset_task();
    begin
        reset = 1;
        start_tx = 0;
        csk_rst_tb = 0;
        payload_length = 0;
        write_enable = 0;
        read_enable = 0;
        addr = 0;
        din = 0;
        @(posedge clk);
        #1;
        reset = 0;
    end
endtask


// Task 1: Test Zero Padding
task test_zero_padding(input [7:0] length);
    integer i;
    integer bit_idx;
    begin
        payload_length = length;
        bit_idx = 0; 
        #1; 
        $display("");
        $display("==============================================");
        $display("    PAYLOAD = %0d BYTES", payload_length);
        $display("    PHR = %b", DUT_ZERO_PADDING.PHR);
        if (payload_length > 0) begin
            for (i = 0; i < payload_length; i = i + 1) begin
                $display("  PSDU BYTE [%0d] / (RAM[%0d]) = %b", i, i, DUT_RAM.mem[i]);
            end
        end
        $display("==============================================");
        $display("");

        @(negedge clk);
        start_tx = 1;
        @(posedge clk);
        #1;
        start_tx = 0;

        wait (padding_valid == 1'b1);
        while (padding_valid) begin
            $display("TIME = %0t | BIT_COUNT = %0d | OUT_BIT = %b",$time,bit_idx,out_bit);
            bit_idx = bit_idx + 1; 
            @(posedge clk);       
            #1;
        end

        $display("");
        $display("==============================================");
        $display("    TOTAL_BITS   = %0d", total_bits);
        $display("    PADDING_BITS = %0d", DUT_ZERO_PADDING.padding_bits);
        $display("    Zero Padding FINISHED");
        $display("==============================================");
        $display("");
    end
endtask


// Task 2: Test DEMUX
task test_demux();
    integer pair_idx;
    begin
        pair_idx = 0; 

        wait (demux_valid_out == 1'b1);
        while (demux_valid_out) begin
            $display("TIME = %0t | DEMUX_BIT_COUNT = %0d | IN_PHASE = %b | QUADRATURE = %b",
                     $time, pair_idx * 2, in_phase, quadrature);
            pair_idx = pair_idx + 1;
            @(posedge clk); 
            #1;
        end

        $display("");
        $display("==============================================");
        $display("    DEMUX FINISHED");
        $display("==============================================");
        $display("");
    end
endtask


// Task 3: Test Symbol Mapper
task test_symbol_mapper();
    integer i_sym_cnt, q_sym_cnt;
    integer expected_symbols;
    begin
        i_sym_cnt = 0;
        q_sym_cnt = 0;
        wait (i_symbol_mapper_valid == 1'b1 || q_symbol_mapper_valid == 1'b1);
        expected_symbols = total_bits / 12;

        // The wait above already consumed the edge of whichever pulse(s)
        // are high on THIS cycle -- handle it now, before the loop's own
        // @(posedge clk) skips past it and silently drops the first symbol.
        if (i_symbol_mapper_valid) begin
            $display("TIME = %0t | I_SYM_COUNT = %0d | 6-BIT_I_SYM = %b (%0d) | 32-BIT_CODEWORD = %h",
                     $time, i_sym_cnt, i_symbol, i_symbol, i_symbol_mapper_out);
            i_sym_cnt = i_sym_cnt + 1;
        end
        if (q_symbol_mapper_valid) begin
            $display("TIME = %0t | Q_SYM_COUNT = %0d | 6-BIT_Q_SYM = %b (%0d) | 32-BIT_CODEWORD = %h",
                     $time, q_sym_cnt, q_symbol, q_symbol, q_symbol_mapper_out);
            q_sym_cnt = q_sym_cnt + 1;
        end

        while (i_sym_cnt < expected_symbols || q_sym_cnt < expected_symbols) begin
            @(posedge clk);
            #1;
            if (i_symbol_mapper_valid) begin
                $display("TIME = %0t | I_SYM_COUNT = %0d | 6-BIT_I_SYM = %b (%0d) | 32-BIT_CODEWORD = %h",
                         $time, i_sym_cnt, i_symbol, i_symbol, i_symbol_mapper_out);
                i_sym_cnt = i_sym_cnt + 1;
            end
            if (q_symbol_mapper_valid) begin
                $display("TIME = %0t | Q_SYM_COUNT = %0d | 6-BIT_Q_SYM = %b (%0d) | 32-BIT_CODEWORD = %h",
                         $time, q_sym_cnt, q_symbol, q_symbol, q_symbol_mapper_out);
                q_sym_cnt = q_sym_cnt + 1;
            end
        end

        $display("");
        $display("==============================================");
        $display("    TOTAL I SYMBOLS = %0d | TOTAL Q SYMBOLS = %0d", i_sym_cnt, q_sym_cnt);
        $display("    SYMBOL MAPPER FINISHED");
        $display("==============================================");
        $display("");
    end
endtask


// Task 4: Test Symbol Buffer & Interleaver
task test_buffer_and_interleaver();
    integer i_blk_cnt, q_blk_cnt;
    integer expected_blocks;
    begin
        i_blk_cnt = 0;
        q_blk_cnt = 0;
        wait (i_buffer_valid == 1'b1 || q_buffer_valid == 1'b1);
        expected_blocks = total_bits / 24;

        // Same reasoning as test_symbol_mapper: handle the pulse the
        // wait above already caught before the loop's @(posedge clk)
        // skips past it.
        if (i_buffer_valid) begin
            $display("TIME = %0t | I_BLOCK_COUNT = %0d | 64-BIT_BUFFER = %b | 64-BIT_INTERLEAVED = %b",
                     $time, i_blk_cnt, i_buffer_out, i_interleaver_out);
            i_blk_cnt = i_blk_cnt + 1;
        end
        if (q_buffer_valid) begin
            $display("TIME = %0t | Q_BLOCK_COUNT = %0d | 64-BIT_BUFFER = %b | 64-BIT_INTERLEAVED = %b",
                     $time, q_blk_cnt, q_buffer_out, q_interleaver_out);
            q_blk_cnt = q_blk_cnt + 1;
        end

        while (i_blk_cnt < expected_blocks || q_blk_cnt < expected_blocks) begin
            @(posedge clk);
            #1;
            if (i_buffer_valid) begin
                $display("TIME = %0t | I_BLOCK_COUNT = %0d | 64-BIT_BUFFER = %b | 64-BIT_INTERLEAVED = %b",
                         $time, i_blk_cnt, i_buffer_out, i_interleaver_out);
                i_blk_cnt = i_blk_cnt + 1;
            end
            if (q_buffer_valid) begin
                $display("TIME = %0t | Q_BLOCK_COUNT = %0d | 64-BIT_BUFFER = %b | 64-BIT_INTERLEAVED = %b",
                         $time, q_blk_cnt, q_buffer_out, q_interleaver_out);
                q_blk_cnt = q_blk_cnt + 1;
            end
        end

        $display("");
        $display("==============================================");
        $display("    TOTAL I BLOCKS = %0d | TOTAL Q BLOCKS = %0d", i_blk_cnt, q_blk_cnt);
        $display("    BUFFER & INTERLEAVER FINISHED");
        $display("==============================================");
        $display("");
    end
endtask


// Task 5: Test Form PPDU 
task test_form_ppdu();
    integer ppdu_cnt;
    integer silence_cnt;
    begin
        ppdu_cnt = 0;
        silence_cnt = 0;
        
        wait (ppdu_valid == 1'b1);

        while (silence_cnt < 20) begin
            if (ppdu_valid) begin
                $display("TIME = %0t | PPDU_CHIP_COUNT = %0d | I_OUT = %b | Q_OUT = %b",
                         $time, ppdu_cnt, ppdu_i_out, ppdu_q_out);
                ppdu_cnt = ppdu_cnt + 1;
                silence_cnt = 0; 
            end else begin
                silence_cnt = silence_cnt + 1;
            end
            @(posedge clk);
            #1;
        end

        $display("");
        $display("==============================================");
        $display("    TOTAL PPDU CHIPS = %0d", ppdu_cnt);
        $display("    FORM PPDU FINISHED");
        $display("==============================================");
        $display("");
    end
endtask


// Task 6: Test QPSK Mapper
task test_qpsk_mapper();
    integer qpsk_cnt;
    integer silence_cnt;
    begin
        qpsk_cnt = 0;
        silence_cnt = 0;
        
        wait (qpsk_valid_out == 1'b1);
        
        while (silence_cnt < 20) begin
            if (qpsk_valid_out) begin
                $display("TIME = %0t | QPSK_CHIP_COUNT = %0d | XN_REAL = %0d | XN_IMAG = %0d",
                         $time, qpsk_cnt, xn_real, xn_imag);
                qpsk_cnt = qpsk_cnt + 1;
                silence_cnt = 0;
            end else begin
                silence_cnt = silence_cnt + 1;
            end
            @(posedge clk);
            #1;
        end

        $display("");
        $display("==============================================");
        $display("    QPSK MAPPER FINISHED (Total chips: %0d)", qpsk_cnt);
        $display("==============================================");
        $display("");
    end
endtask


// Task 7: Test DQPSK Encoder
task test_dqpsk_encoder();
    integer dqpsk_cnt;
    integer silence_cnt;
    begin
        dqpsk_cnt = 0;
        silence_cnt = 0;
        
        wait (dqpsk_out_valid == 1'b1);

        while (silence_cnt < 20) begin
            if (dqpsk_out_valid) begin
                $display("TIME = %0t | DQPSK_CHIP_COUNT = %0d | IN_PHASE_CHIP = %b | MAPPED_IN_PHASE = %0d | OUT_PHASE = %0d (0x%h)",
                         $time, dqpsk_cnt, ppdu_i_out, DUT_DQPSK_ENCODER.in_phase, dqpsk_out_phase, dqpsk_out_phase);
                dqpsk_cnt = dqpsk_cnt + 1;
                silence_cnt = 0;
            end else begin
                silence_cnt = silence_cnt + 1;
            end
            @(posedge clk);
            #1;
        end

        $display("");
        $display("==============================================");
        $display("    DQPSK ENCODER FINISHED (Total chips: %0d)", dqpsk_cnt);
        $display("==============================================");
        $display("");
    end
endtask


// Task 8: Test CSK Generator (Runs alongside the DQPSK Encoder)
task test_csk_generator();
    integer csk_cnt;
    integer silence_cnt;
    begin
        csk_cnt = 0;
        silence_cnt = 0;
        
        // 1. Wait until the REAL transmission start (tx_start) so the
        //    CSK generator's address counter resets in lockstep with
        //    PPDU's actual first output chip, not with padding_done
        //    (which fires much earlier, before interleaving is done).
        wait (tx_start == 1'b1);
        @(negedge clk);
        csk_rst_tb = 1;
        @(posedge clk);
        #1;
        csk_rst_tb = 0; // The generator is now perfectly aligned with PPDU!

        // 2. Wait for DQPSK valid to align the print statements
        wait (dqpsk_out_valid == 1'b1);

        // 3. Monitor the output stream
        while (silence_cnt < 20) begin
            if (dqpsk_out_valid) begin
                $display("TIME = %0t | CSK_CHIP_COUNT = %0d | CSK_REAL_OUT = %b | CSK_IMAG_OUT = %b",
                         $time, csk_cnt, csk_real_out, csk_imag_out);
                csk_cnt = csk_cnt + 1;
                silence_cnt = 0;
            end else begin
                silence_cnt = silence_cnt + 1;
            end
            @(posedge clk);
            #1;
        end

        $display("");
        $display("==============================================");
        $display("    CSK GENERATOR FINISHED (Total loops monitored: %0d)", csk_cnt);
        $display("==============================================");
        $display("");
    end
endtask


// Task 9: Test Final DQCSK Modulator Output (the actual CSS transmit signal)
task test_final_output();
    integer tx_cnt;
    integer silence_cnt;
    begin
        tx_cnt = 0;
        silence_cnt = 0;

        wait (tx_valid == 1'b1);

        while (silence_cnt < 20) begin
            if (tx_valid) begin
                // NOTE: tx_real/tx_imag are registered outputs of
                // dqcsk_modulator -- they already correctly reflect
                // whichever sn_phase/csk sample produced them. We don't
                // also print those inputs here, since reading them
                // combinationally at this point would show THIS cycle's
                // values, not the (possibly earlier, if PPDU paused)
                // values that actually produced this tx sample.
                $display("TIME = %0t | TX_COUNT = %0d | TX_REAL = %0d | TX_IMAG = %0d",
                         $time, tx_cnt, $signed(tx_real), $signed(tx_imag));
                tx_cnt = tx_cnt + 1;
                silence_cnt = 0;
            end else begin
                silence_cnt = silence_cnt + 1;
            end
            @(posedge clk);
            #1;
        end

        $display("");
        $display("==============================================");
        $display("    FINAL DQCSK OUTPUT FINISHED (Total chips: %0d)", tx_cnt);
        $display("==============================================");
        $display("");
    end
endtask


// Main Test Initial Block
initial begin
    reset_task();
    #20;
    
    // First stage
    test_zero_padding(8'd12);
    
    // Remaining stages wait via their specific valid flags and run sequentially based on data flow
    fork
        begin test_demux() ;end
        begin test_symbol_mapper();end
        begin test_buffer_and_interleaver();end
        begin test_form_ppdu();end
        begin test_qpsk_mapper();end
        begin test_dqpsk_encoder();end
        begin test_csk_generator();end
        begin test_final_output();end
    join

    #50;
    $display("==============================================");
    $display("    ALL TESTS FINISHED SUCCESSFULLY");
    $display("==============================================");
    $finish;
end
//tx_real = csk_real − csk_imag, tx_imag = csk_real + csk_imag.
endmodule