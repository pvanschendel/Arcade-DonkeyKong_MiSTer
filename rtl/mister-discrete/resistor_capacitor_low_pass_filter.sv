/********************************************************************************\
 *
 *  MiSTer Discrete resistor_capacitor_low_pass filter
 *
 *  Copyright 2022 by Jegor van Opdorp.
 *  This program is free software under the terms of the GPLv3, see LICENCSE.txt
 *
 *  based on https://en.wikipedia.org/wiki/Low-pass_filter
 *  and https://zipcpu.com/dsp/2017/08/19/simple-filter.html
 *
 ********************************************************************************/
module resistor_capacitor_low_pass_filter #(
    parameter SAMPLE_RATE = 48000,
    parameter real R = 47000,  // Ohm
    parameter real C = 47e-9   // F
) (
    input clk,
    input I_RSTn,
    input audio_clk_en,
    input signed[15:0] in,
    output signed[15:0] out = 0
);
    localparam R_C_NORMALIZED = R * C * SAMPLE_RATE;
    localparam I_MULTIPLIER = 32'(int'((2.0**16) / (1.0 + R_C_NORMALIZED)));

    always@(posedge clk, negedge I_RSTn) begin
        if(!I_RSTn) begin
            out <= 0;
        end else if(audio_clk_en) begin
            out <= out + 16'((I_MULTIPLIER * (in - out)) >>> 16);
        end
    end

endmodule