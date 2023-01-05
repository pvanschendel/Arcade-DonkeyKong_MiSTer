/*********************************************************************************\
 *
 *  MiSTer Discrete invertor square wave oscilator
 *
 *  Copyright 2022 by Jegor van Opdorp.
 *  This program is free software under the terms of the GPLv3, see LICENCSE.txt
 *
 *
 *  Simplified model of the below circuit.
 *  This model does not take the  transfer functions of the invertors
 *  into account:
 *
 *  f = 1 / (2.2 R1 C1)
 *  This equation was found on:
 *  https://www.gadgetronicx.com/square-wave-generator-logic-gates/
 *
 *        |\        |\
 *        | \       | \
 *     +--|  >o--+--|-->o--+-------> out
 *     |  | /    |  | /    |
 *     |  |/     |  |/     |
 *     Z         Z         |
 *     Z         Z R1     --- C
 *     Z         Z        ---
 *     |         |         |
 *     '---------+---------'
 *
 *     Drawing based on a drawing from MAME discrete
 *
 *********************************************************************************/
module invertor_square_wave_oscilator#(
    parameter int SIGNAL_FRACTION_WIDTH = 14, // VCC corresponds to in[SIGNAL_FRACTION_WIDTH] = 1, others = 0.
    parameter real VCC = 12, // [V]
    parameter real CLOCK_RATE = 50000000, // [Hz]
    parameter real SAMPLE_RATE = 48000, // [Hz]
    parameter real R1 = 4300, // [Ohm]
    parameter real C = 10e-6 // [F]
) (
    input clk,
    input I_RSTn,
    input audio_clk_en,
    output signed[15:0] out
);
    localparam SIGNAL_WIDTH = 16;
    localparam int PERIOD_COUNT = CLOCK_RATE * (2.2 * R1 * C);
    localparam HALF_PERIOD_COUNT = PERIOD_COUNT >> 1;

    localparam int SIGNAL_MULTIPLIER = (1<<<SIGNAL_FRACTION_WIDTH);
    `define VOLTAGE_TO_SIGNAL(VOLTAGE) \
        SIGNAL_WIDTH'(SIGNAL_MULTIPLIER * ((VOLTAGE) / VCC))

    reg [31:0] period_counter;
    reg signed[SIGNAL_WIDTH-1:0] unfiltered_out;
    always@(posedge clk, negedge I_RSTn) begin
        if(!I_RSTn)begin
            period_counter <= 0;
            unfiltered_out <= 0;
        end else begin
            if(period_counter < PERIOD_COUNT)begin
                period_counter <= period_counter + 1;
            end else begin
                period_counter <= 0;
            end

            if (audio_clk_en) begin
                // TODO: fix bug: we are outputting 12 V here, will also influence slew rate limiter:
                unfiltered_out <=  period_counter < HALF_PERIOD_COUNT ? `VOLTAGE_TO_SIGNAL(12.0) : '0;
            end
        end
    end

    // filter to simulate transfer rate of invertors
    rate_of_change_limiter #(
        .SIGNAL_FRACTION_WIDTH(SIGNAL_FRACTION_WIDTH),
        .VCC(VCC),
        .SAMPLE_RATE(SAMPLE_RATE),
        .MAX_CHANGE_RATE(1000) // [V/s]
    ) slew_rate (
        .clk(clk),
        .I_RSTn(I_RSTn),
        .audio_clk_en(audio_clk_en),
        .in(unfiltered_out),
        .out(out)
    );
endmodule