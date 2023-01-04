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
    output signed[15:0] out
);
    localparam int signal_width = 16;
    localparam int multiplier_width = signal_width * 2;
    localparam int fraction_width = signal_width - 1; // all bits in fraction, except sign bit
    localparam int fraction_mutliplier = (1<<<fraction_width);
    localparam R_C_NORMALIZED = R * C * SAMPLE_RATE;
    localparam I_MULTIPLIER = 1.0 / (1.0 + R_C_NORMALIZED);

    wire [multiplier_width - 1:0] integrand;
    assign integrand =
        multiplier_width'(fraction_mutliplier * I_MULTIPLIER) * signal_width'(in - out);
    reg [multiplier_width - 1:0] integral; // does this really need to be a reg ?
    always@(posedge clk, negedge I_RSTn) begin
        if(!I_RSTn) begin
            integral <= 0;
        end else if(audio_clk_en) begin
            integral <= integral + integrand;
        end
    end

    assign out = integral[multiplier_width-1:multiplier_width-signal_width];
endmodule