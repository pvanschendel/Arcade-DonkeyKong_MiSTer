module rate_of_change_limiter #(
    parameter int SIGNAL_FRACTION_WIDTH = 14, // VCC corresponds to in[SIGNAL_FRACTION_WIDTH] = 1, others = 0.
    parameter real VCC = 12, // [V]
    parameter real SAMPLE_RATE = 48000, // [Hz]
    parameter real MAX_CHANGE_RATE = 1000 // [V/s]
) (
    input clk,
    input I_RSTn,
    input audio_clk_en,
    input signed[15:0] in,
    output reg signed[15:0] out = 0
);
    localparam NORMALIZED_RATE = MAX_CHANGE_RATE / (VCC * SAMPLE_RATE);
    localparam int SIGNAL_MULTIPLIER = (1<<<SIGNAL_FRACTION_WIDTH);
    localparam int MAX_CHANGE_PER_SAMPLE = SIGNAL_MULTIPLIER * NORMALIZED_RATE;

    wire signed[16:0] difference = in - out;
    always@(posedge clk, negedge I_RSTn) begin
        if(!I_RSTn)begin
            out <= 0;
        end else if(audio_clk_en) begin
            out <=
                (difference < -MAX_CHANGE_PER_SAMPLE) ? out - 16'(MAX_CHANGE_PER_SAMPLE) :
                (difference >  MAX_CHANGE_PER_SAMPLE) ? out + 16'(MAX_CHANGE_PER_SAMPLE) :
                in;
        end
    end
endmodule