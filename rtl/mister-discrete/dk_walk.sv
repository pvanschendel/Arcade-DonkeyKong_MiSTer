/********************************************************************************\
 *
 *  MiSTer Discrete example circuit - dk walk
 *
 *  Copyright 2022 by Jegor van Opdorp.
 *  This program is free software under the terms of the GPLv3, see LICENCSE.txt
 *
 ********************************************************************************/
module dk_walk #(
    parameter CLOCK_RATE = 1000000,
    parameter SAMPLE_RATE = 48000
)(
    input clk,
    input I_RSTn,
    input audio_clk_en,
    input walk_en,
    output reg signed[15:0] out = 0
);
    localparam int SIGNAL_WIDTH = 16;
    localparam int SIGNAL_FRACTION_WIDTH = SIGNAL_WIDTH - 2; // use one sign bit and one bit to prevent overflow.
    localparam int SIGNAL_MULTIPLIER = (1<<<SIGNAL_FRACTION_WIDTH);
    localparam VCC = 12.0; // [V], this seems to be wrong, all parts have +(/-)5V supply voltage, but leave current code for now.
    `define VOLTAGE_TO_SIGNAL(VOLTAGE) \
        SIGNAL_WIDTH'(SIGNAL_MULTIPLIER * ((VOLTAGE) / VCC))

    // convert boolean to numerical signal
    wire signed[SIGNAL_WIDTH-1:0] signal_walk = walk_en ? '0 : `VOLTAGE_TO_SIGNAL(5.0);

    // TODO: value assumed from previous code, maybe depends on value of
    // pull-up resistor R36, so it may not be a not be a general property of LS05.
    localparam LS05_slew_rate = 100000; // [V/s]
    wire signed[SIGNAL_WIDTH-1:0] W_6L_8_signal_walk_rate_limted;
    rate_of_change_limiter #(
        .VCC(VCC),
        .SAMPLE_RATE(SAMPLE_RATE),
        .MAX_CHANGE_RATE(LS05_slew_rate),
        .SIGNAL_FRACTION_WIDTH(SIGNAL_FRACTION_WIDTH)
    ) U_6L_8_slew_rate (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .in(signal_walk),
        .out(W_6L_8_signal_walk_rate_limted)
    );

    localparam C30 = 10e-6; // [F]
    localparam R47 = 4.3e3 * 1.02; // [Ohm]
    // -> frequency = 10 Hz
    wire signed[SIGNAL_WIDTH-1:0] W_8L_12_square_wave;
    invertor_square_wave_oscilator#(
        .SIGNAL_FRACTION_WIDTH(SIGNAL_FRACTION_WIDTH),
        .VCC(VCC),
        .CLOCK_RATE(CLOCK_RATE),
        .SAMPLE_RATE(SAMPLE_RATE),
        .R1(R47),
        .C(C30)
    ) U_8L_12_square_wave (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .out(W_8L_12_square_wave)
    );

/*
    wire signed[SIGNAL_WIDTH-1:0] mixer_input[1:0] = '{W_6L_8_signal_walk_rate_limted, W_8L_12_square_wave};
    localparam R45 = 10e3;
    localparam R46_plus_R36 = 12e3 * 1.07 + 1e3; // 1.07 fudge factor
    wire signed[SIGNAL_WIDTH-1:0] v_control; // This signal cannot be measured, because the next stage heavily loads above the pass frequency
    resistive_two_way_mixer #(
        .R0(R45),
        .R1(R46_plus_R36)
    ) v_control_adder (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .inputs(mixer_input),
        .out(v_control)
    );

    localparam R44 = 1.2e3; // [Ohm] TODO instead of R44, use the output resistance of the mixer, R44 is not significant in comparison.
    localparam C29 = 3.3e-6; // [F]
    // f_cutoff = 1 / (2 pi R C) = 13 Hz; t_c = 12 ms
    wire signed[SIGNAL_WIDTH-1:0] v_control_filtered;
    resistor_capacitor_low_pass_filter #(
        .SAMPLE_RATE(SAMPLE_RATE),
        .R(R44),
        .C(C29)
    ) v_control_filter (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .in(v_control),
        .out(v_control_filtered)
    );
*/

   //  `define RANGE_PARAM_REAL(name) ``name``_range_val
   //  `define WIDTH_PARAM_REAL(name) ``name``_width_val
   //  `define EXPONENT_PARAM_REAL(name) ``name``_exponent_val

    wire signed[SIGNAL_WIDTH-1:0] v_control_filtered;
    WalkEnAstable555 #(
        .signal_width(SIGNAL_WIDTH)
    ) NetworkEnAstable (
        .clk(clk),
        .rst(~I_RSTn),
        .clk_en(audio_clk_en),
        .walk_en(W_6L_8_signal_walk_rate_limted),
        .square_wave(W_8L_12_square_wave),
        .vcc(`VOLTAGE_TO_SIGNAL(5.0)),
        .v_control(v_control_filtered)
    );

    localparam R42 = 47e3; // [Ohm]
    localparam R43 = 27e3; // [Ohm]
    localparam C28 = 33e-9; // [F]

    // t_l = 0.61ms, t_h = 1/3VCC: 0.54ms, 2/3VCC: 1.69 ms - > t_total = 1.15 - 2.30 ms
    // 870 -> 869 - 434 Hz
    // Current FPGA recording:
    // low: 650 high: 1300 Hz, first down to 300Hz
    //
    // PCB:
    // Steady state: OSC low: 600 Hz, High: 850 Hz
    // At start, first down to 350 Hz
    // Original FPGA
    // Steady state: OSC low: 580 Hz, High: 850 Hz
    // At start, first down to 500 Hz
    // The pull-up of the low control voltage is due to the internal v_control voltage
    // divider of the 555. Assuming here it is 5kOhm to 5V, 10kOhm to GND
    // The division by 2 (should be 2/3) is due to the load of the high voltage by the same divider.
    // It would be better to handle the two-way mixer, low-pass and this divider in one entity.

    wire signed[SIGNAL_WIDTH-1:0] W_8N_5_astable_555;
    astable_555_vco #(
        .CLOCK_RATE(CLOCK_RATE),
        .SAMPLE_RATE(SAMPLE_RATE),
        .R1(R42),
        .R2(R43),
        .C(C28)
    ) U_8N_5_vco (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .v_control(v_control_filtered),
        .out(W_8N_5_astable_555)
    );

    localparam R18_plus_R17 = 9.2e3; // [Ohm] not sure what this should be
    localparam C25 = 3.3e-6; // [F]
    wire signed[SIGNAL_WIDTH-1:0] walk_en_filtered;
    resistor_capacitor_high_pass_filter #(
        .SAMPLE_RATE(SAMPLE_RATE),
        .R(R18_plus_R17),
        .C(C25)
    ) walk_en_filter (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .in(W_6L_8_signal_walk_rate_limted),
        .out(walk_en_filtered)
    );

    // TODO: Diode hack below is structurally part of walk_en_filtered, and should connect to Q6

    // TODO: This seems to have opposite logic: a high transistor base voltage should pull down walk_en_filtered
    localparam BC1815_threshold_voltage = 0.73; // [V] TODO: value assumed from previous code
    wire signed[SIGNAL_WIDTH-1:0] W_Q6_C_walk_enveloped =
        W_8N_5_astable_555 > `VOLTAGE_TO_SIGNAL(BC1815_threshold_voltage) ? `VOLTAGE_TO_SIGNAL(0.015) : walk_en_filtered; // instead of 0, use 0.05 V or so: there is a faint vibration even if no step is made.

    // TODO: The output bandpass stage should have a pass gain of 0.5, but it does not:

    localparam R16_plus_R15 = 2e3; // [Ohm] Schematic says 11.2k !?
    localparam C23 = 4.7e-6; // [F]
    wire signed[SIGNAL_WIDTH-1:0] walk_enveloped_high_passed;
    resistor_capacitor_high_pass_filter #(
        .SAMPLE_RATE(SAMPLE_RATE),
        .R(R16_plus_R15),
        .C(C23)
    ) output_filter_hp (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .in(W_Q6_C_walk_enveloped),
        .out(walk_enveloped_high_passed)
    );

    localparam R16 = 5.6e3 * 0.65; // [Ohm] schematic has 5.6K
    localparam C22 = 47e-9; // [F]
    wire signed[SIGNAL_WIDTH-1:0] walk_enveloped_band_passed;
    resistor_capacitor_low_pass_filter #(
        .SAMPLE_RATE(SAMPLE_RATE),
        .R(R16),
        .C(C22)
    ) output_filter_lp (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .in(walk_enveloped_high_passed),
        .out(walk_enveloped_band_passed)
    );

    //TODO: hack to simulate diode D5 to ground
    always @(posedge clk, negedge I_RSTn) begin
        if(!I_RSTn)begin
            out <= 0;
        end else if(audio_clk_en)begin
            if(walk_enveloped_band_passed > 0) begin
                out <= walk_enveloped_band_passed + (walk_enveloped_band_passed >>> 1); // * 1.5
            end else begin
                out <= (walk_enveloped_band_passed >>> 1) + (walk_enveloped_band_passed >>> 2); // * 0.75
            end
        end
    end

endmodule