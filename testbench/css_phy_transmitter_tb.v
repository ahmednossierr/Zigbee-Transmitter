`timescale 1ns/1ps

module css_phy_transmitter_tb();

reg clk;
reg reset;
reg start_Tx;
reg [7:0]  payloadLength;
wire   done_Tx;
wire [7:0] Tx_real;
wire [7:0] Tx_imag;

// Instantiate the Top Level Transmitter
css_phy_transmitter DUT (
    .clk           (clk),
    .reset         (reset),
    .start_Tx      (start_Tx),
    .payloadLength (payloadLength),
    .done_Tx       (done_Tx),
    .Tx_real       (Tx_real),
    .Tx_imag       (Tx_imag)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// Reset Task
task reset_task();
begin
    reset = 1;
    start_Tx = 0;
    payloadLength = 0;
    @(posedge clk);
    #1;
    reset = 0;
    #20;
end
endtask

// -------------------------------------------------------------------------
// Self-Checking Task for a Test Case
// -------------------------------------------------------------------------
//
// CHIP-RATE CHECK -- one golden line per RTL output sample, in order.
//
// expected_Tx_real/imag_len*.txt are MATLAB's full chip-rate output: every
// group of 4 DQPSK symbols is expanded into 4 held-phase subchirps of 38
// samples each (152 active samples), followed by a literal zero-valued gap
// of Teven or Todd samples (Table 42), alternating even/odd group by group.
// css_phy_transmitter.v now implements that expansion in chirp_gap_engine.v
// (see that file for the full design rationale), so DUT.tx_valid pulses
// once per CHIP SAMPLE (not once per DQPSK symbol as it used to), in the
// same order as the golden files. A plain 1:1 comparison is therefore the
// correct and sufficient check -- no decimation/skipping needed.
task run_testcase(input [7:0] len);
    integer fd_r, fd_i;
    integer status_r, status_i;
    reg [5:0] exp_r, exp_i;
    integer errors, samples;
    reg [2047:0] file_payload;
    reg [2047:0] file_real;
    reg [2047:0] file_imag;
begin
    // Format the paths to the MATLAB generated files
    $sformat(file_payload, "D:/personal/Education/Career/Digital_IC/Courses/ITI/Zigbee_Project/Final_Submission/Codes/Scripts/Matlab_scripts/payload_in_len%0d.txt", len);
    $sformat(file_real,    "D:/personal/Education/Career/Digital_IC/Courses/ITI/Zigbee_Project/Final_Submission/Codes/Scripts/Matlab_scripts/expected_Tx_real_len%0d.txt", len);
    $sformat(file_imag,    "D:/personal/Education/Career/Digital_IC/Courses/ITI/Zigbee_Project/Final_Submission/Codes/Scripts/Matlab_scripts/expected_Tx_imag_len%0d.txt", len);

    $display("===================================================================");
    $display(" RUNNING TEST CASE: Payload Length = %0d bytes  (SYMBOL-RATE check)", len);
    $display("===================================================================");

    // 1. Load the payload into DUT's internal RAM
    $readmemb(file_payload, DUT.u_ram.mem);

    // 2. Open expected output files
    fd_r = $fopen(file_real, "r");
    fd_i = $fopen(file_imag, "r");

    if (fd_r == 0 || fd_i == 0) begin
        $display("ERROR: Could not open expected files for length %0d. Make sure MATLAB generated them!", len);
    end else begin
        errors = 0;
        samples = 0;

        // 3. Start the transmission
        payloadLength = len;
        @(negedge clk);
        start_Tx = 1;
        @(posedge clk);
        #1;
        start_Tx = 0;

        // 4. Monitor outputs when tx_valid is HIGH
        while (!done_Tx) begin
            @(posedge clk);
            #1; // Sample shortly after clock edge

            if (DUT.tx_valid) begin // Secretly tap into internal tx_valid wire
                status_r = $fscanf(fd_r, "%b\n", exp_r);
                status_i = $fscanf(fd_i, "%b\n", exp_i);

                if (status_r != 1 || status_i != 1) begin
                    $display("ERROR: Reached end of expected file prematurely at sample %0d", samples);
                end else begin
                    // Compare outputs. Since Tx is 8-bit sign extended, we check the lower 6 bits
                    if (Tx_real[5:0] !== exp_r || Tx_imag[5:0] !== exp_i) begin
                        if (errors < 10) begin // Print only first 10 errors to avoid spam
                            $display("  MISMATCH at sample %0d: Expected Real=%b Imag=%b | Got Real=%b Imag=%b",
                                     samples, exp_r, exp_i, Tx_real[5:0], Tx_imag[5:0]);
                        end
                        errors = errors + 1;
                    end
                end
                samples = samples + 1;
            end
        end

        // 5. Report Results
        $display("-------------------------------------------------------------------");
        $display(" TEST CASE COMPLETED (Len = %0d bytes)", len);
        $display(" Total Samples Checked = %0d  (chip-rate: 1 sample per RTL output)", samples);
        $display(" Total Errors          = %0d", errors);
        if (errors == 0)
            $display(" >>> RESULT: PASS <<<");
        else
            $display(" >>> RESULT: FAIL <<<");
        $display("===================================================================\n");

        $fclose(fd_r);
        $fclose(fd_i);
    end

    // Idle time between testcases
    #100;
end
endtask

// -------------------------------------------------------------------------
// Main Test Sequence
// -------------------------------------------------------------------------
initial begin
    $display("\nSTARTING CSS PHY TRANSMITTER MULTI-TESTBENCH\n");
    reset_task();
    
    // Run the 4 test cases automatically
    run_testcase(8'd5);
    run_testcase(8'd20);
    run_testcase(8'd55);
    run_testcase(8'd125);
    
    $display("ALL TEST CASES FINISHED.");
    $finish;
end

endmodule