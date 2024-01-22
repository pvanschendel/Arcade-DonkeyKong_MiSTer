/********************************************************************************\
 *
 *  low pass filter with 2 variable inputs and 2 fixed inputs.
 *
 *            R_F[0]
 *  V_F[0] o---####--+
 *                   |
 *            R_F[1] |
 *  V_F[1] o---####--+
 *                   |
 *            R_S[0] |
 *  in[0]  o---####--+-----------+--o out
 *                   |           |
 *            R_S[1] |        C ===
 *  in[1]  o---####--+           |
 *                               V GND
 *
 * C dout/dt = (in[0] - out)/R_S[0] + (in[1] - out)/R_S[1] + ...
 * C dout/dt = 1/R_S[0] * in[0] + ...  - (1/R_S[0] + ...) * out
 * Euler integration:
 * out_next = out + dt/(C*R_S[0]) * in[0] + ... (1 - dt/C*(1/R_S[0] + ...) * out
 *
 *  Copyright 2023 by Pieter van Schendel.
 *  This program is free software under the terms of the GPLv3, see LICENCSE.txt
 *
 *             R45      R44
 *  in[0]  o---####--+--####---o out
 *                   |
 *             R46   |
 *  in[1]  o---####--+
 *
 *                   ==
 *
 *            R_S[0]
 *  in[0]  o---####--+--o out
 *                   |
 *            R_S[1] |
 *  in[1]  o---####--+
 *
 *  R_S[0] = R45 + R44//R46 = 11.1e3
 *  R_S[1] = R46 + R44//R46 = 13.1e3
 ********************************************************************************/
module resistor_capacitor_low_pass_filter_2s_2f #(
    parameter real SAMPLE_RATE = 48000, // [Hz]
    parameter SIGNAL_WIDTH = 16,

    parameter SIGNAL_COUNT = 2,
    parameter FIXED_COUNT = 2,
    parameter real C = 47e-9 // [F]
    parameter real R_S[SIGNAL_COUNT] = {11.1e3, 13.1e3}, // [Ohm]
    parameter real R_F[FIXED_COUNT] = {5e3, 10e3}, // [Ohm]
    parameter real V_F[FIXED_COUNT] = {5.0, 0.0} // [Volt]
) (
    input clk,
    input rst,
    input clk_en, // should have frequency SAMPLE_RATE
    input signed[SIGNAL_WIDTH-1:0] in[SIGNAL_COUNT],
    output signed[SIGNAL_WIDTH-1:0] out
);
    localparam int MULTIPLIER_WIDTH = SIGNAL_WIDTH * 2;
    localparam int FRACTION_WIDTH = SIGNAL_WIDTH - 1; // all bits in fraction, except sign bit
    localparam int FRACTION_MULTIPLIER = (1<<<FRACTION_WIDTH);

    localparam real S_Gain[SIGNAL_COUNT] = {1/(SAMPLE_RATE * C * R_S[0]), 1/(SAMPLE_RATE * C * R_S[1])}; // = 0.0005687505687505687, 0.0004819184208497186
    localparam real S_Fix = V_F[0] / (SAMPLE_RATE * C *R_F[0]) + V_F[1] / (SAMPLE_RATE * C *R_F[0]); // = 0.006313131313131312 [V]
    localparam R_ground = 1/(1/R_S[0] + 1/R_S[1] + 1/R_F[0] + 1/R_F[0]); // Resistance to ground = 2144 [Ohm]
    localparam I_Gain = 1/(SAMPLE_RATE * C * R_ground); // = 0.002944608383539681

    // Resources could be optimized using consecutive MAC operations:
    wire [MULTIPLIER_WIDTH-1:0] integrand;
    assign integrand =
        MULTIPLIER_WIDTH'(FRACTION_MULTIPLIER * S_Fix) +
        + MULTIPLIER_WIDTH'(FRACTION_MULTIPLIER * S_Gain[0]) * in[0]
        + MULTIPLIER_WIDTH'(FRACTION_MULTIPLIER * S_Gain[1]) * in[1]
        - MULTIPLIER_WIDTH'(FRACTION_MULTIPLIER * R_C_NORMALIZED) * out;
    reg [MULTIPLIER_WIDTH-1:0] integral;
    always@(posedge clk, negedge I_RSTn) begin
        if(!I_RSTn) begin
            integral <= 0;
        end else if(audio_clk_en) begin
            integral <= integral + integrand;
        end
    end

    assign out = integral[MULTIPLIER_WIDTH-1:MULTIPLIER_WIDTH-SIGNAL_WIDTH];

endmodule