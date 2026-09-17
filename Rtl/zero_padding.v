module zero_padding( clk , reset , start_tx , payload_length , PSDU ,
                     out_bit , valid_out , padding_done , padded_data , total_bits);

parameter Data_Rate = 250 ;

// Define Inputs and Outputs 

input clk , reset , start_tx ;

input [7:0] payload_length ;

// 127 * 8= 1016

input [1015:0] PSDU;

// PHR = 12 bit , PSDU = 8*127=1016  , output zero padding = 1016+12+24

output reg out_bit;

output reg valid_out;

output reg padding_done;

output reg [1031:0] padded_data;

output reg [10:0] total_bits;
//
wire [11:0] PHR ;

assign PHR = {5'b00000 , payload_length[6:0]};

//
    
reg [4:0] padding_bits ;

reg [10:0] bit_count;


//Making Zero padding 

always @(posedge clk ) begin

    if (reset) begin

        padding_bits <= 0;
        total_bits <= 0;
        bit_count <= 0;
        out_bit <= 0;
        valid_out <= 0;
        padding_done <= 0;
        padded_data <= 0;

    end 

    else if (start_tx) begin

        padding_done <= 0;

        if (Data_Rate == 250) begin

            padding_bits <= (24 - ((12 + (8 * payload_length)) % 24)) % 24;

            total_bits <= 12 + (8 * payload_length) + 
                          ((24 - ((12 + (8 * payload_length)) % 24)) % 24);//padding bits

        end

        else begin //Data rate = 1Mb/s

            padding_bits <= (6 - ((12 + (8 * payload_length)) % 6)) % 6;

            total_bits <= 12 + (8 * payload_length) + 
                          ((6 - ((12 + (8 * payload_length)) % 6)) % 6);

        end

        out_bit <= PHR[0];
        padded_data[0] <= PHR[0];
        bit_count <= 1;
        valid_out <= 1;

    end 

    else if (valid_out) begin

        if (bit_count < 12) begin

            out_bit <= PHR[bit_count];

            if (bit_count < total_bits)
                padded_data[bit_count] <= PHR[bit_count];

        end

        else if (bit_count < (12 + (8 * payload_length))) begin

        out_bit <= PSDU[bit_count - 12];

        if (bit_count < total_bits)
            padded_data[bit_count] <= PSDU[bit_count - 12];

        end

        else begin

            out_bit <= 0;

            if (bit_count < total_bits)
                padded_data[bit_count] <= 0;

        end


        if (bit_count == total_bits ) begin

            valid_out <= 0;
            padding_done <= 1;
            bit_count <= 0;

        end

        else begin
            bit_count <= bit_count + 1;
        end

    end

    else begin
        padding_done <= 0;
    end

end

endmodule
