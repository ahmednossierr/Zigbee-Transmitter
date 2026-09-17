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
/* 8 bits needs to convert into 1016 bit to be in PSDU
suppose ram contains
RAM[0] = 8A
RAM[1] = 2A
RAM[2] = A1
RAM[3] = F3
...
so we want
PSDU[7:0]    = RAM[0]
PSDU[15:8]   = RAM[1]
PSDU[23:16]  = RAM[2]
PSDU[31:24]  = RAM[3]
...

BIT-ORDER FIX: payload_in_lenN.txt is loaded via $readmemb, whose convention
is leftmost character = MSB (mem[i][7]) and rightmost character = LSB
(mem[i][0]). The MATLAB reference transmits each payload byte's bits
left-to-right as written (i.e. the byte's MSB, mem[i][7], is the FIRST bit
of that byte to enter the PHR+PSDU bitstream, and its LSB, mem[i][0], is
the LAST). PSDU[i*8] is the first bit of byte i consumed downstream (by
zero_padding.v: padded_data[12 + i*8 + 0] = PSDU[i*8 + 0]), so it must equal
mem[i][7], not mem[i][0]. A straight `psdu_out[i*8+:8] = mem[i]` (no
reversal) sends each byte out LSB-first instead, which happens to be
unobservable for the PHR (byte-independent, all-zero/short fields) and for
the first codeword of the payload's own first byte in some cases, but
diverges from the golden expected_Tx_*_lenN.txt files as soon as a
downstream chip actually depends on a mid/high-order payload bit --
confirmed by an independent bit-exact Python re-implementation of the full
MATLAB chain (PHR -> demux -> S/P -> codeword -> interleave -> preamble/SFD
-> QPSK -> DQPSK -> chirp/gap) diverging from golden at the exact same
point (sample 4771, the first payload-derived DQPSK symbol) until this
per-byte bit reversal was applied, after which all 4 golden files
(len=5/20/55/125) matched with 0 mismatches. See conventions-and-bugs
project memory for the full derivation.
*/
genvar i;
generate
    for (i = 0; i < 127; i = i + 1) begin
        assign psdu_out[i*8 +: 8] = {mem[i][0], mem[i][1], mem[i][2], mem[i][3],
                                      mem[i][4], mem[i][5], mem[i][6], mem[i][7]};
    end
endgenerate

endmodule
