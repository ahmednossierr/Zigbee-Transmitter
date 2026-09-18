module ram ( clk , reset , write_enable , read_enable , addr ,din ,dout ,psdu_out );
//Define Inputs and Outputs
input   clk;
input   reset ;   
input   write_enable;  
input   read_enable; 
input   [6:0] addr;   
input   [7:0] din;
output reg  [7:0] dout ;
output [1015:0] psdu_out;

//Define memory 
reg [7:0] mem [0:126];

always @(posedge clk) begin
    if (reset) dout<= 0;
    else begin
        if (write_enable) mem[addr] <= din;
        if (read_enable)  dout      <= mem[addr]; 
    end
end

genvar i;
generate
    for (i = 0; i < 127; i = i + 1) begin
        assign psdu_out[i*8 +: 8] = {mem[i][0], mem[i][1], mem[i][2], mem[i][3],
                                      mem[i][4], mem[i][5], mem[i][6], mem[i][7]};
    end
endgenerate

endmodule
