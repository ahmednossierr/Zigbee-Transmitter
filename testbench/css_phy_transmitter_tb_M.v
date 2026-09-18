`timescale 1ns/1ps

module css_phy_transmitter_tb_M();

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
        $display("ERROR: Could not open expected files for length %0d.", len);
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

            if (DUT.tx_valid) begin 
                status_r = $fscanf(fd_r, "%b\n", exp_r);
                status_i = $fscanf(fd_i, "%b\n", exp_i);

                if (status_r != 1 || status_i != 1) begin
                    $display("ERROR: Reached end of expected file prematurely at sample %0d", samples);
                end else begin
                    
                    if (Tx_real[5:0] !== exp_r || Tx_imag[5:0] !== exp_i) begin
                        if (errors < 10) begin 
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
