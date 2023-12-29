/********************************************************************************\
 *
 *  MiSTer Discrete resistive two way mixer
 *
 *  Copyright 2022 by Jegor van Opdorp.
 *  This program is free software under the terms of the GPLv3, see LICENCSE.txt
 *
 *   inputs[0]    inputs[1]
 *        V         V
 *        |         |
 *        |         |
 *        Z         Z
 *     R0 Z         Z R1
 *        Z         Z
 *        |         |
 *        '----,----'
 *             |
 *             |
 *             V
 *            out
 *
 * This assumes that input 0 and 1 are driven by voltage outputs with
 * low enough output inpedance, and out drives a voltage input with high enough
 * input inpedance. (high and low enough compared to R0 and R1 at all
 * relveant frequencies)
 *
 ********************************************************************************/
module resistive_two_way_mixer #(
    parameter real R0 = 10000,
    parameter real R1 = 10000
) (
    input clk,
    input I_RSTn,
    input audio_clk_en,
    input[15:0] inputs[1:0],
    output reg[15:0] out
);
    localparam ampl_reduction = 0.33; // due to subsequent resisitive load
    localparam int signal_width = 16;
    localparam int multiplier_width = signal_width * 2;
    localparam int fraction_width = signal_width - 1; // all bits in fraction, except sign bit
    localparam int fraction_mutliplier = (1<<<fraction_width);
    localparam IN0_FACTOR = ampl_reduction * R1 / (R0 + R1);
    localparam IN1_FACTOR = 1.3 * ampl_reduction * R0 / (R0 + R1);  // 1.3 to get deep enough frequency dip at start

    always@(posedge clk, negedge I_RSTn) begin
        if(!I_RSTn)begin
            out <= 0;
        end else if(audio_clk_en)begin
            out <= signal_width'((
                multiplier_width'(fraction_mutliplier * IN0_FACTOR) * inputs[0] +
                multiplier_width'(fraction_mutliplier * IN1_FACTOR) * inputs[1]) >>> fraction_width);
        end
    end
endmodule