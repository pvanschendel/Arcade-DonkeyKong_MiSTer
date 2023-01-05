/********************************************************************************\
 *
 *  MiSTer Discrete invertor square wave oscilator test bench
 *
 *  Copyright 2022 by Jegor van Opdorp.
 *  This program is free software under the terms of the GPLv3, see LICENCSE.txt
 *
 *  Model taken from the equation in answer by tardate (not accepted answer) on:
 *  https://electronics.stackexchange.com/questions/101530/what-is-the-equation-for-the-555-timer-control-voltage
 *
 *  th=C⋅(R1+R2)⋅ln(1+v_control/(2*(VCC−v_control)))
 *  tl=C⋅R2⋅ln(2)
 *
 *           v_pos
 *              V
 *              |
 *        .-----+---+-----------------------------.
 *        |         |                             |
 *        |         |                             |
 *        |         |                             |
 *        Z         |8                            |
 *     R1 Z     .---------.                       |
 *        |    7|  Vcc    |                       |
 *        +-----|Discharge|                       |
 *        |     |         |                       |
 *        Z     |   555   |3                      |
 *     R2 Z     |      Out|---> Output Node       |
 *        |    6|         |                       |
 *        +-----|Threshold|                       |
 *        |     |         |                       |
 *        +-----|Trigger  |                       |
 *        |    2|         |---< Control Voltage   |
 *        |     |  Reset  |5                      |
 *        |     '---------'                       |
 *       ---        4|                            |
 *     C ---         +----------------------------'
 *        |          |
 *        |          ^
 *       gnd       Reset
 *
 *     Drawing based on a drawing from MAME discrete
 *
 ********************************************************************************/
module astable_555_vco#(
    parameter int SIGNAL_FRACTION_WIDTH = 14, // VCC corresponds to in[SIGNAL_FRACTION_WIDTH] = 1, others = 0.
    parameter real VCC = 12.0, // [V]
    parameter real CLOCK_RATE = 50e6, // [Hz]
    parameter real SAMPLE_RATE = 48e3, // [Hz]
    parameter real R1 = 47e3, // [Ohm]
    parameter real R2 = 27e3, // [Ohm]
    parameter real C = 33e-9 // [F]
) (
    input clk,
    input I_RSTn,
    input audio_clk_en,
    input signed[15:0] v_control,
    output signed[15:0] out
);
    localparam SIGNAL_WIDTH = 16;
    localparam int SIGNAL_MULTIPLIER = (1<<<SIGNAL_FRACTION_WIDTH);
    `define VOLTAGE_TO_SIGNAL(VOLTAGE) \
        SIGNAL_WIDTH'(SIGNAL_MULTIPLIER * ((VOLTAGE) / VCC))

    localparam int SIG_5V = `VOLTAGE_TO_SIGNAL(5.0);
    localparam real LN_2 = 0.6931471805599453;
    localparam int CYCLES_LOW = C * R2 * LN_2 * CLOCK_RATE;
    localparam int NORMALIZED_C_R1_R2 = C * (R1 + R2) * CLOCK_RATE;

    // TODO: once we have v_control configured correcly, this may not be
    // necessary anymore:
    // Only safe if v_control is positive:
    wire signed[SIGNAL_WIDTH-1:0] v_control_safe = v_control < 16'h7fff ? v_control : 16'h7ffe;
    wire [SIGNAL_WIDTH-1:0] two_5_v_minus_vcontrol = SIGNAL_WIDTH'((SIG_5V << 1) - (v_control_safe << 1));

    reg[23:0] to_log_8_shifted;
    wire [11:0] ln_vc_vcc_vc_8_shifted;
    natural_log natlog(
        .in_8_shifted(to_log_8_shifted),
        .I_RSTn(I_RSTn),
        .clk(clk),
        .out_8_shifted(ln_vc_vcc_vc_8_shifted)
    );

    reg[SIGNAL_WIDTH-1:0] v_control_divided_two_5_v_minus_vcontrol = 3000;
    reg[31:0] cycles_high;
    always @(posedge clk, negedge I_RSTn) begin
        if(!I_RSTn)begin
            to_log_8_shifted <= 0;
            cycles_high <= 1000;
        end else begin
            v_control_divided_two_5_v_minus_vcontrol <= v_control_safe / (two_5_v_minus_vcontrol >> 8);
            to_log_8_shifted <= 24'((1 << 8) + v_control_divided_two_5_v_minus_vcontrol);
            cycles_high <= ((NORMALIZED_C_R1_R2 >> 4) * ln_vc_vcc_vc_8_shifted) >> 4; // C⋅(R1+R2)⋅ln(1+v_control/(2*(VCC−v_control)))
        end
    end
    wire [32:0] wave_length = cycles_high + CYCLES_LOW;

    reg[63:0] wave_length_counter;
    reg signed[SIGNAL_WIDTH-1:0] unfiltered_out;
    always @(posedge clk, negedge I_RSTn) begin
        if(!I_RSTn)begin
            wave_length_counter <= 0;
            unfiltered_out <= 0;
        end else begin
            wave_length_counter <= (wave_length_counter < wave_length) ?
                wave_length_counter + 1 : '0;

            if(audio_clk_en)begin
                unfiltered_out <= wave_length_counter < cycles_high ? SIGNAL_WIDTH'(SIG_5V) : '0;
            end
        end
    end

    rate_of_change_limiter #(
        .SIGNAL_FRACTION_WIDTH(SIGNAL_FRACTION_WIDTH),
        .VCC(VCC),
        .SAMPLE_RATE(SAMPLE_RATE),
        .MAX_CHANGE_RATE(200000)
    ) slew_rate (
        clk,
        I_RSTn,
        audio_clk_en,
        unfiltered_out,
        out
    );
endmodule