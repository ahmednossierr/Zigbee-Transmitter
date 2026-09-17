module interleaver_250kbps (
    input  wire [63:0] block_in,
    output wire [63:0] block_out
);

localparam NUM_GROUPS  = 16;
localparam GROUP_WIDTH = 4;

localparam [63:0] INTERLEAVE_PERM = {4'd3 , 4'd14 , 4'd1 , 4'd12 , 4'd7  ,  4'd10 ,  4'd5  , 4'd8
                                    ,4'd11, 4'd6  , 4'd9 , 4'd4  , 4'd15 ,  4'd2  ,  4'd13 , 4'd0   
};

genvar i;
generate 
    for (i=0; i < NUM_GROUPS; i=i+1 ) begin : gen_interleaver
        assign block_out[63-GROUP_WIDTH*i -: GROUP_WIDTH] = block_in[63-GROUP_WIDTH*INTERLEAVE_PERM[i*4 +: 4] -: GROUP_WIDTH];
        
    end
    
endgenerate
    
endmodule

