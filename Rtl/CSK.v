module ROM(address, data_out);

parameter DATA_WIDTH = 8;
parameter NUM_WORDS  = 256;
parameter FILE_flag = 1'b0;
parameter FILE_name = "rom_data.txt";

localparam ADDR_WIDTH = $clog2(NUM_WORDS);

input [ADDR_WIDTH-1:0] address;
output [DATA_WIDTH-1:0] data_out;

reg [DATA_WIDTH-1:0] mem [NUM_WORDS-1:0];

assign data_out = mem [address];

initial begin

if(FILE_flag == 1'b1) begin

	$readmemb(FILE_name, mem);
end
end


endmodule


module timer(clk, reset, value_out);

parameter TIMER_WIDTH = 8;

input clk, reset;

output reg [TIMER_WIDTH-1:0] value_out;

always @(posedge clk) begin

	if(reset)
		value_out <= 0;
	else
		value_out <= value_out +1;



end

endmodule





module CSK_ROM(address, imag_out, real_out);

parameter NUM_SAMPLES = 152;

input[7:0] address;
output [5:0] imag_out, real_out;

ROM #(
	.DATA_WIDTH (6),
	.NUM_WORDS (NUM_SAMPLES),
	.FILE_flag (1'b1),
	.FILE_name ("D:/personal/Education/Career/Digital_IC/Courses/ITI/Zigbee_Project/Final_Submission/Codes/Scripts/Our_scripts/chirpSequenceReal_tofile.txt")
) chirp_r  (address, real_out);


ROM #(
	.DATA_WIDTH (6),
	.NUM_WORDS (NUM_SAMPLES),
	.FILE_flag (1'b1),
	.FILE_name ("D:/personal/Education/Career/Digital_IC/Courses/ITI/Zigbee_Project/Final_Submission/Codes/Scripts/Our_scripts/imag_test.txt")
) chirp_I  (address, imag_out);

endmodule

module CSK_generator (clk, CSK_rst, imag_out, real_out);

localparam NUM_SAMPLES = 152;

input clk, CSK_rst;
output [5:0] imag_out, real_out;

wire timer_reset;
wire [7:0] address;



timer #(.TIMER_WIDTH (8)) chirp_timer (.clk(clk), .reset(timer_reset), .value_out(address));

CSK_ROM #(.NUM_SAMPLES (NUM_SAMPLES)) chirp_seq (.address(address), .imag_out(imag_out), .real_out(real_out));


assign timer_reset = CSK_rst | (address >= NUM_SAMPLES-1);

endmodule




module CSK_generator_tb ();

reg clk, CSK_rst;
reg [5:0] exp_imag_out, exp_real_out;
wire [5:0] act_imag_out, act_real_out;


integer file_r, file_i, status_r, status_i;

CSK_generator DUT (clk, CSK_rst, act_imag_out, act_real_out);


initial begin
clk = 0;
	while (1) begin
	#5
	clk = ~ clk;
	end


end

initial begin

CSK_rst = 1; #20
CSK_rst = 0;





        file_i = $fopen("imag_test.txt", "r");
        file_r = $fopen("real_test.txt", "r");


        while (!$feof(file_r)) begin
            status_i = $fscanf(file_i, "%b\n", exp_imag_out);
            status_r = $fscanf(file_r, "%b\n", exp_real_out);

            if (act_real_out !== exp_real_out || act_imag_out !== exp_imag_out) begin
                $display("FAIL | address:%b | act_real_out:%b act_imag_out:%b | \exp_real_out:%b exp_imag_out:%b ",
                          DUT.address, act_real_out, act_imag_out, exp_real_out, exp_imag_out);

            end
		#10;
        end
        $fclose(file_r);
        $fclose(file_i);
        $finish;


end


endmodule

