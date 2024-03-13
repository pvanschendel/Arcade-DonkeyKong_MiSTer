// Model generated on 2023-12-30 11:43:34.443002
// Using anasysmod and
//
// ```python
// class WalkEnAstable555(MixedSignalModel):
//     R44 = 1200
//     R45 = 10000
//     R46 = 12000
//     C29 = 0.0000033
//     R_555_pullup = 5000
//     R_555_pulldown = 10000

//     def __init__(self, name='WalkEnAstable555', dt=1/96000):
//         # call the super constructor
//         super().__init__(name, dt=dt)

//         # define I/O
//         self.add_analog_input('walk_en')
//         self.add_analog_input('square_wave')
//         self.add_analog_input('vcc') # 12V, seems like this shouldn't be an input, but it doesn't compile otherwise
//         self.add_analog_output('v_control')
//
//         c = self.make_circuit()
//         gnd = c.make_ground()
//
//         c.voltage('net_walk_en', gnd, self.walk_en)
//         c.voltage('net_square_wave', gnd, self.square_wave)
//         c.voltage('net_vcc', gnd, self.vcc)
//
//         c.resistor('net_walk_en', 'net_mix', self.R45)
//         c.resistor('net_square_wave', 'net_mix', self.R46)
//         c.resistor('net_mix', 'net_v_control', self.R44)
//         c.capacitor('net_v_control', gnd, self.C29, voltage_range=RangeOf(self.v_control))
//         c.resistor('net_v_control', 'net_vcc', self.R_555_pullup)
//         c.resistor('net_v_control', 'net_gnd', self.R_555_pulldown)
//
//         c.add_eqns(
//             AnalogSignal('net_v_control') == self.v_control
//         )
// ```

module WalkEnAstable555 #(
    parameter signal_width = 16
) (
    input clk,
    input rst,
    input clk_en, // parameters calculated for 96kHz
    input signed [signal_width-1:0] walk_en,
    input signed [signal_width-1:0] square_wave,
    input signed [signal_width-1:0] vcc,
    output signed [signal_width-1:0] v_control
);
   //  // Declaring internal variables.
   //  `MAKE_REAL(tmp_circ_4, `RANGE_PARAM_REAL(v_control));
   //  // Assign signal: tmp_circ_4
   //  `MUL_CONST_REAL(0.9988949512946891, tmp_circ_4, tmp0);
   //  `MUL_CONST_REAL(0.00021549311726031938, square_wave, tmp1);
   //  `MUL_CONST_REAL(0.0006309638473382152, vcc, tmp2);
   //  `MUL_CONST_REAL(0.0002585917407123833, walk_en, tmp3);
   //  `ADD_REAL(tmp0, tmp1, tmp4);
   //  `ADD_REAL(tmp2, tmp3, tmp5);
   //  `ADD_REAL(tmp4, tmp5, tmp6); // tmp6 = tmp_circ_4 * 0.9988949512946891 + square_wave * 0.00021549311726031938 + vcc * 0.0006309638473382152 + walk_en * 0.0002585917407123833
   //  `DFF_INTO_REAL(tmp6, tmp_circ_4, `RST_MSDSL, `CLK_MSDSL, 1'b1, 0);
   //  // Assign signal: v_control
   //  wire signed [signal_width-1:0] integrator = v_control * signal_width' >>> signal_width
    localparam int multiplicand_width = signal_width;
    localparam int multiplicand_fraction = multiplicand_width - 1; // this does mean we can at most multiply with 0.9999..
    localparam int fraction_shift = 2**(multiplicand_fraction);
    localparam int mult_result_width = multiplicand_width + signal_width;

	 localparam signed [multiplicand_width-1:0] v_control_mul = 0.9977899025 * fraction_shift;
    wire signed [mult_result_width-1:0] v_control_part = v_control_i[signal_width-1:0] * v_control_mul;

    localparam signed [multiplicand_width-1:0] square_wave_mul = 0.000430986 * fraction_shift;
    wire signed [mult_result_width-1:0] square_wave_part = square_wave * square_wave_mul;

    localparam signed [multiplicand_width-1:0] vcc_mul = 0.001261927 * fraction_shift;
    wire signed [mult_result_width-1:0] vcc_part = vcc * vcc_mul;

    localparam signed [multiplicand_width-1:0] walk_en_mul = 0.000517183 * fraction_shift;
    wire signed [mult_result_width-1:0] walk_en_part = walk_en * walk_en_mul;

    localparam int extend_add = 2; // = log2ceil(number_of_additions)
    localparam int add_width = mult_result_width + extend_add;
    wire signed [add_width - 1:0] add_result =
        {{extend_add{1'b0}}, v_control_part} +
        {{extend_add{1'b0}}, square_wave_part} +
        {{extend_add{1'b0}}, vcc_part} +
        {{extend_add{1'b0}}, walk_en_part};

    localparam int v_control_i_width = signal_width + 4;
    reg signed [v_control_i_width-1:0] v_control_i;
    always@(posedge clk, posedge rst) begin
        if(rst)begin
            v_control_i <= 0;
        end else if(clk_en)begin
            // handle adder overflow:
            v_control_i <= add_result[add_width-1] ^ add_result[add_width-2] ?
               {add_result[v_control_i_width-1], {(v_control_i_width-1){add_result[v_control_i_width-extend_add]}}} :
               add_result[add_width - extend_add - 1:add_width - extend_add - v_control_i_width];
        end
    end

    assign v_control = v_control_i[v_control_i_width - 1:v_control_i_width-signal_width];
endmodule