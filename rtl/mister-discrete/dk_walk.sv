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
    wire signed[15:0] square_osc_out;
    wire signed[15:0] v_control;
    wire signed[15:0] mixer_input[1:0];

    wire signed[15:0] walk_en_5volts;
    wire signed[15:0] walk_en_5volts_filtered;
    assign walk_en_5volts =  walk_en ? '0 : 16'd6826; // 2^14 * 5/12 = 6826 , for 5 volts

    // filter to simulate transfer rate of invertors
    rate_of_change_limiter #(
        .SAMPLE_RATE(SAMPLE_RATE),
        .MAX_CHANGE_RATE(950)
    ) slew_rate (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .in(walk_en_5volts),
        .out(walk_en_5volts_filtered)
    );

    assign mixer_input[0] = walk_en_5volts_filtered;
    assign mixer_input[1] = square_osc_out;

    wire signed[15:0] walk_en_filtered;
    wire signed[15:0] astable_555_out;

    invertor_square_wave_oscilator#(
        .CLOCK_RATE(CLOCK_RATE),
        .SAMPLE_RATE(SAMPLE_RATE),
        .R1(4100),// sligtly slower R, to simulate slower freq due to transfer rate of inverters
        .C_MICROFARADS_16_SHIFTED(655360)
    ) square (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .out(square_osc_out)
    );

    localparam R45 = 10e3;
    localparam R46 = 12e3;
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

    wire signed[15:0] v_control_filtered;

    localparam R44 = 1.2e3 * 3.08; //TODO schematic has 1.2k, but 3700 a closer response, probably need a better low pass implementation
    localparam C29 = 3.3e-6;
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
    astable_555_vco #(
        .CLOCK_RATE(CLOCK_RATE),
        .SAMPLE_RATE(SAMPLE_RATE),
        .R1(47000),
        .R2(27000),
        .C_35_SHIFTED(1134)
    ) vco (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .v_control((v_control_filtered >>> 1) + 16'd5900),
        .out(astable_555_out)
    );

    resistor_capacitor_high_pass_filter #(
        .SAMPLE_RATE(SAMPLE_RATE),
        .R(9200), // not sure what this should be
        .C_35_SHIFTED(113387)
    ) filter1 (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .in(walk_en_5volts_filtered),
        .out(walk_en_filtered)
    );

    wire signed[15:0] walk_enveloped;
    assign walk_enveloped = astable_555_out > 1000 ? walk_en_filtered : 16'd0;

    wire signed[15:0] walk_enveloped_high_passed;

    resistor_capacitor_high_pass_filter #(
        .SAMPLE_RATE(SAMPLE_RATE),
        .R(2000),
        .C_35_SHIFTED(161491)
    ) filter2 (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .in(walk_enveloped),
        .out(walk_enveloped_high_passed)
    );

    wire signed[15:0] walk_enveloped_band_passed;

    localparam R16 = 5.6e3 * 0.536; // schematic has 5.6K
    localparam C22 = 47e-9;
    resistor_capacitor_low_pass_filter #(
        .SAMPLE_RATE(SAMPLE_RATE),
        .R(R16),
        .C(C22)
    ) filter3 (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .in(walk_enveloped_high_passed),
        .out(walk_enveloped_band_passed)
    );

    always @(posedge clk, negedge I_RSTn) begin
        if(!I_RSTn)begin
            out <= 0;
        end else if(audio_clk_en)begin
            if(walk_enveloped_band_passed > 0) begin //TODO: hack to simulate diode connection coming from ground
                out <= walk_enveloped_band_passed + (walk_enveloped_band_passed >>> 1);
            end else begin
                out <= (walk_enveloped_band_passed >>> 1) + (walk_enveloped_band_passed >>> 2);
            end
        end
    end

endmodule