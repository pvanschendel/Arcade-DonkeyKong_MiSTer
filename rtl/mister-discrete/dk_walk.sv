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

    // convert boolean to numerical signal
    wire signed[SIGNAL_WIDTH-1:0] signal_walk = walk_en ? '0 : 16'd6827;

    // filter to simulate transfer rate of invertors
    wire signed[SIGNAL_WIDTH-1:0] W_6L_8_signal_walk_rate_limted;
    rate_of_change_limiter #(
        .SAMPLE_RATE(SAMPLE_RATE),
        .MAX_CHANGE_RATE(950)
    ) U_6L_8_slew_rate (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .in(signal_walk),
        .out(W_6L_8_signal_walk_rate_limted)
    );

    localparam R47 = 4100; // [Ohm] schematic: 4.3k, sligtly slower R, to simulate slower freq due to transfer rate of inverters
    localparam C30_MICROFARADS_16_SHIFTED = 655360; // = 10 [uF] * 2.0**16
    wire signed[SIGNAL_WIDTH-1:0] W_8L_12_square_wave;
    invertor_square_wave_oscilator#(
        .CLOCK_RATE(CLOCK_RATE),
        .SAMPLE_RATE(SAMPLE_RATE),
        .R1(R47),
        .C_MICROFARADS_16_SHIFTED(C30_MICROFARADS_16_SHIFTED)
	 ) U_8L_12_square_wave (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .out(W_8L_12_square_wave)
    );

    wire signed[SIGNAL_WIDTH-1:0] mixer_input[1:0] = '{W_6L_8_signal_walk_rate_limted, W_8L_12_square_wave};
    localparam R45 = 10e3;
    localparam R46 = 12e3;
    wire signed[SIGNAL_WIDTH-1:0] v_control; // This signal cannot be measured, because the next stage heavily loads above the pass frequency
    resistive_two_way_mixer #(
        .R0(R45),
        .R1(R46)
    ) v_control_adder (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .inputs(mixer_input),
        .out(v_control)
    );

    localparam R44 = 1.2e3 * 3.08; // [Ohm] TODO schematic has 1.2k, but 3700 a closer response, probably need a better low pass implementation
    localparam C29 = 3.3e-6; // [F]
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

    //TODO: properly calculate influence of 555 timer on input voltage
    localparam R42 = 47000; // [Ohm]
    localparam R43 = 27000; // [Ohm]
    wire signed[SIGNAL_WIDTH-1:0] W_8N_5_astable_555;
    astable_555_vco #(
        .CLOCK_RATE(CLOCK_RATE),
        .SAMPLE_RATE(SAMPLE_RATE),
        .R1(R42),
        .R2(R43),
        .C_35_SHIFTED(1134)
    ) U_8N_5_vco (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .v_control((v_control_filtered >>> 1) + SIGNAL_WIDTH'(5900)), // this is probably the TODO above
        .out(W_8N_5_astable_555)
    );

    localparam R18_plus_R17 = 9200; // [Ohm] not sure what this should be
    localparam C25_35_SHIFTED = 113387; // = 3.3e-6 [F] * 2.0**35
    wire signed[SIGNAL_WIDTH-1:0] walk_en_filtered;
    resistor_capacitor_high_pass_filter #(
        .SAMPLE_RATE(SAMPLE_RATE),
        .R(R18_plus_R17),
        .C_35_SHIFTED(C25_35_SHIFTED)
    ) walk_en_filter (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .in(W_6L_8_signal_walk_rate_limted),
        .out(walk_en_filtered)
    );

    // TODO: Diode hack below is structurally part of walk_en_filtered, and should connect to Q6

    wire signed[SIGNAL_WIDTH-1:0] W_Q6_C_walk_enveloped = W_8N_5_astable_555 > 1000 ? walk_en_filtered : '0;

    // TODO: The output bandpass stage should have a pass gain of 0.5, but it does not:

    localparam R16_plus_R15 = 2000; // [Ohm] Schematic says 11.2k !?
    localparam C23_35_SHIFTED = 161491; // = 4.7e-6 [F] * 2.0**35
    wire signed[SIGNAL_WIDTH-1:0] walk_enveloped_high_passed;
    resistor_capacitor_high_pass_filter #(
        .SAMPLE_RATE(SAMPLE_RATE),
        .R(R16_plus_R15),
        .C_35_SHIFTED(C23_35_SHIFTED)
    ) output_filter_hp (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .in(W_Q6_C_walk_enveloped),
        .out(walk_enveloped_high_passed)
    );

    localparam R16 = 5.6e3 * 0.536; // [Ohm] schematic has 5.6K
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