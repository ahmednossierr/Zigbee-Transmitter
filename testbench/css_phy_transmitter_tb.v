module css_phy_transmitter_tb();
reg clk;
reg reset;
reg start_Tx;
reg [7:0]  payloadLength;
wire   done_Tx;
wire [7:0] Tx_real;
wire [7:0] Tx_imag;

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
//Reeset Task
task reset_task();
        begin
            reset = 1;
            start_Tx = 0;
            payloadLength = 0;
            @(posedge clk);
            #1;
            reset = 0;
        end
    endtask

    // Start a transmission  
task start_transmission(input [7:0] length);
        integer i;
        begin
            payloadLength = length;
            #1;
            $display("");
            $display("==============================================");
            $display("    PAYLOAD = %0d BYTES", payloadLength);
            for (i = 0; i < payloadLength; i = i + 1) begin
                $display("    PSDU BYTE [%0d] (RAM[%0d]) = %b", i, i, DUT.u_ram.mem[i]);
            end
            $display("==============================================");
            $display("");

            @(negedge clk);
            start_Tx = 1;
            @(posedge clk);
            #1;
            start_Tx = 0;
        end
    endtask

//Task monitor 
task monitor_output();
        integer tx_cnt;
        begin
            tx_cnt = 0;
            wait (DUT.tx_valid == 1'b1);
            while (!done_Tx || DUT.tx_valid) begin
                if (DUT.tx_valid) begin
                    $display("TIME = %0t | TX_COUNT = %0d | Tx_real = %0d | Tx_imag = %0d",
                             $time, tx_cnt, $signed(Tx_real), $signed(Tx_imag));
                    tx_cnt = tx_cnt + 1;
                end
                @(posedge clk);
                #1;
            end
            $display("");
            $display("==============================================");
            $display(" TOTAL TX SAMPLES = %0d", tx_cnt);
            $display("==============================================");
            $display("");
        end
    endtask

    // Main test sequence
    initial begin
        reset_task();
        #20;
        start_transmission(8'd4);
        fork
            monitor_output();
        join
        #50;
        $display("==============================================");
        $display(" FINISHED SUCCESSFULLY");
        $display("==============================================");
        $finish;
    end

endmodule