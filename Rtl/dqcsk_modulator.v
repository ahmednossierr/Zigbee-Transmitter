module dqcsk_modulator (
    input  wire              clk,
    input  wire              reset,
    input  wire              valid_in,
    input  wire [2:0]        sn_phase,   // from dqpsk_encoder.out_phase (only can take values  1,3,5,7 -- 45/135/225/315 deg)
    input  wire signed [5:0] csk_real,
    input  wire signed [5:0] csk_imag,

    output reg               valid_out,
    output reg  signed [7:0] tx_real,
    output reg  signed [7:0] tx_imag
);

   
    function signed [7:0] sat6;
        input signed [7:0] val;
        begin
            if (val > 8'sd31)
                sat6 = 8'sd31;
            else if (val < -8'sd32)
                sat6 = -8'sd32;
            else
                sat6 = val;
        end
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            valid_out <= 1'b0;
            tx_real   <= 8'sd0;
            tx_imag   <= 8'sd0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                case (sn_phase)
                    3'd1: begin // 45 deg:  Sn = +1 +j1
                        tx_real <= sat6(csk_real - csk_imag);
                        tx_imag <= sat6(csk_real + csk_imag);
                    end
                    3'd3: begin // 135 deg: Sn = -1 +j1
                        tx_real <= sat6(-csk_real - csk_imag);
                        tx_imag <= sat6( csk_real - csk_imag);
                    end
                    3'd5: begin // 225 deg: Sn = -1 -j1
                        tx_real <= sat6( csk_imag - csk_real);
                        tx_imag <= sat6(-csk_real - csk_imag);
                    end
                    3'd7: begin // 315 deg: Sn = +1 -j1
                        tx_real <= sat6(csk_real + csk_imag);
                        tx_imag <= sat6(csk_imag - csk_real);
                    end
                    default: begin
                        tx_real <= 8'sd0;
                        tx_imag <= 8'sd0;
                    end
                endcase
            end
        end
    end

endmodule
