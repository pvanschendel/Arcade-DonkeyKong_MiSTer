/********************************************************************************\
 *
 *  MiSTer Discrete resistor_capacitor_low_pass filter
 *
 *  Copyright 2022 by Jegor van Opdorp.
 *  This program is free software under the terms of the GPLv3, see LICENCSE.txt
 *
 *  based on https://en.wikipedia.org/wiki/Low-pass_filter
 *
 ********************************************************************************/
module resistor_capacitor_high_pass_filter #(
    parameter SAMPLE_RATE = 48000, // [Hz]
    parameter R = 47000, // [Ohm]
    parameter C = 47e-9 // [F]
) (
    input clk,
    input I_RSTn,
    input audio_clk_en,
    input signed[15:0] in,
    output reg signed[15:0] out
);
    localparam int SIGNAL_WIDTH = 16;
    localparam int MULTIPLIER_WIDTH = SIGNAL_WIDTH * 2;
    localparam int FRACTION_WIDTH = SIGNAL_WIDTH; // all bits in fraction, including sign bit !?
    localparam int FRACTION_MULTIPLIER = (1<<<FRACTION_WIDTH);

    localparam R_C_NORMALIZED = R * C * SAMPLE_RATE;
    localparam int SMOOTHING_FACTOR_ALPHA_16_SHIFTED = FRACTION_MULTIPLIER * R_C_NORMALIZED / (R_C_NORMALIZED + 1.0);

    wire[7:0] random_number;
    LFSR lfsr(
        .clk(clk),
        .audio_clk_en(audio_clk_en),
        .I_RSTn(I_RSTn),
        .LFSR(random_number)
    );

    reg signed[15:0] last_in;
    always@(posedge clk, negedge I_RSTn) begin
        if(!I_RSTn)begin
            out <= 0;
            last_in <= 0;
        end else if(audio_clk_en)begin
            out <= SIGNAL_WIDTH'((SMOOTHING_FACTOR_ALPHA_16_SHIFTED * (out + in - last_in)) >>> FRACTION_WIDTH);
            last_in <= SIGNAL_WIDTH'(in + ((random_number >>> 6) - 2)); // add noise to help convergence to 0
        end
    end

endmodule