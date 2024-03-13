// Model generated on 2023-12-30 11:43:34.443002

//`timescale 1ns/1ps

//`include "svreal.sv"

// fixed-point representation defaults
// (can override by defining them externally)
`ifndef SHORT_WIDTH_REAL
    `define SHORT_WIDTH_REAL 18
`endif

`ifndef LONG_WIDTH_REAL
    `define LONG_WIDTH_REAL 25
`endif


`define ABS_MATH(a) \
    (((a) > 0) ? (a) : (-(a)))

`define FIXED_TO_FLOAT(significand, exponent) \
    ((significand)*(2.0**(exponent)))

`define FLOAT_TO_FIXED(value, exponent) \
    ((real'(value))*(2.0**(-(exponent))))

`define RANGE_PARAM_REAL(name) ``name``_range_val
`define WIDTH_PARAM_REAL(name) ``name``_width_val
`define EXPONENT_PARAM_REAL(name) ``name``_exponent_val
`define DECL_REAL(port) \
    parameter real `RANGE_PARAM_REAL(port) = 0, \
    parameter integer `WIDTH_PARAM_REAL(port) = 0, \
    parameter integer `EXPONENT_PARAM_REAL(port) = 0

`define DATA_TYPE_REAL(width_expr) \
    `ifdef FLOAT_REAL \
        real \
    `elsif HARD_FLOAT \
        logic [(`HARD_FLOAT_SIGN_BIT):0] \
    `else \
        logic signed [((width_expr)-1):0] \
    `endif

`define PASS_REAL(port, name) \
    .`RANGE_PARAM_REAL(port)(`RANGE_PARAM_REAL(name)), \
    .`WIDTH_PARAM_REAL(port)(`WIDTH_PARAM_REAL(name)), \
    .`EXPONENT_PARAM_REAL(port)(`EXPONENT_PARAM_REAL(name))

`define PORT_REAL(port) \
    `ifdef FLOAT_REAL \
        `DATA_TYPE_REAL(`WIDTH_PARAM_REAL(port)) port \
    `else \
        wire `DATA_TYPE_REAL(`WIDTH_PARAM_REAL(port)) port \
    `endif
`define INPUT_REAL(port) input `PORT_REAL(port)
`define OUTPUT_REAL(port) output `PORT_REAL(port)

`define FROM_REAL(expr, name) \
    `ifdef FLOAT_REAL \
        (expr) \
    `elsif HARD_FLOAT \
        (`REAL_TO_REC_FN(expr)) \
    `else \
		(`FLOAT_TO_FIXED((expr), (`EXPONENT_PARAM_REAL(name)))) \
    `endif

// `define MAKE_FORMAT_REAL(name, range_expr, width_expr, exponent_expr) \
`define MAKE_FORMAT_REAL(name, range_expr, width_expr, exponent_expr) \
    `DATA_TYPE_REAL(width_expr) name; \
    localparam real `RANGE_PARAM_REAL(name) = range_expr; \
    localparam integer `WIDTH_PARAM_REAL(name) = width_expr; \
    localparam integer `EXPONENT_PARAM_REAL(name) = exponent_expr \
   //  `ifdef RANGE_ASSERTIONS \
   //      ; `ASSERTION_REAL(name) \
   //  `endif

`define COPY_FORMAT_REAL(in_name, out_name) \
    `MAKE_FORMAT_REAL(out_name, `RANGE_PARAM_REAL(in_name), `WIDTH_PARAM_REAL(in_name), `EXPONENT_PARAM_REAL(in_name))

// declare a more generic version of $clog2 that supports
// real number inputs, which is needed to automatically
// compute exponents.  the the value returned is
// int(ceil(log2(x)))
// function int clog2_math(input real x);
//     clog2_math = 0;
//     if (x > 0) begin
//         while (x < (2.0**(clog2_math))) begin
//             clog2_math = clog2_math - 1;
//         end
//         while (x > (2.0**(clog2_math))) begin
//             clog2_math = clog2_math + 1;
//         end
//     end
// endfunction
`define CALC_EXP(range, width) ($clog2(int'(real'(range)*(2.0**30)/((2.0**((width)-1))-1.0))) - 30)

`define MAKE_GENERIC_REAL(name, range_expr, width_expr) \
    `MAKE_FORMAT_REAL(name, range_expr, width_expr, `CALC_EXP(range_expr, width_expr))
`define MAKE_LONG_REAL(name, range_expr) \
    `MAKE_GENERIC_REAL(name, range_expr, `LONG_WIDTH_REAL)
`define MAKE_REAL(name, range_expr) \
    `MAKE_LONG_REAL(name, range_expr)

`define ASSIGN_REAL(in_name, out_name) \
    assign_real #( \
        `PASS_REAL(in, in_name), \
        `PASS_REAL(out, out_name) \
    ) assign_real_``out_name``_i ( \
        .in(in_name), \
        .out(out_name) \
    )

`define ASSIGN_CONST_REAL(const_expr, name) \
    assign name = `FROM_REAL(const_expr, name)

// WTF: 1.01* ?
`define CONST_RANGE_REAL(const_expr) \
    (1.01*`ABS_MATH(const_expr))
`define MAKE_GENERIC_CONST_REAL(const_expr, name, width_expr) \
    `MAKE_GENERIC_REAL(name, `CONST_RANGE_REAL(const_expr), width_expr); \
    `ASSIGN_CONST_REAL(const_expr, name)

`define MUL_INTO_REAL(a_name, b_name, c_name) \
    mul_real #( \
        `PASS_REAL(a, a_name), \
        `PASS_REAL(b, b_name), \
        `PASS_REAL(c, c_name) \
    ) mul_real_``c_name``_i ( \
        .a(a_name), \
        .b(b_name), \
        .c(c_name) \
    )
`define MUL_CONST_INTO_REAL_GENERIC(const_expr, in_name, out_name, const_width) \
    `MAKE_GENERIC_CONST_REAL(const_expr, zzz_tmp_``out_name``, const_width); \
    `MUL_INTO_REAL(zzz_tmp_``out_name``, in_name, out_name)
`define MUL_CONST_REAL_GENERIC(const_expr, in_name, out_name, const_width, out_width) \
    `MAKE_GENERIC_REAL(out_name, `CONST_RANGE_REAL(const_expr)*`RANGE_PARAM_REAL(in_name), out_width); \
    `MUL_CONST_INTO_REAL_GENERIC(const_expr, in_name, out_name, const_width)
`define MUL_CONST_REAL(const_expr, in_name, out_name) \
    `MUL_CONST_REAL_GENERIC(const_expr, in_name, out_name, `SHORT_WIDTH_REAL, `LONG_WIDTH_REAL)

// addition of two variables
`define ADD_OPCODE_REAL 0
`define SUB_OPCODE_REAL 1
`define ADD_SUB_INTO_REAL(opcode_value, a_name, b_name, c_name) \
    add_sub_real #( \
        `PASS_REAL(a, a_name), \
        `PASS_REAL(b, b_name), \
        `PASS_REAL(c, c_name), \
		.opcode(opcode_value) \
    ) add_sub_real_``c_name``_i ( \
        .a(a_name), \
        .b(b_name), \
        .c(c_name) \
    )
`define ADD_INTO_REAL(a_name, b_name, c_name) \
    `ADD_SUB_INTO_REAL(`ADD_OPCODE_REAL, a_name, b_name, c_name)
`define ADD_REAL_GENERIC(a_name, b_name, c_name, c_width) \
    `MAKE_GENERIC_REAL(c_name, `RANGE_PARAM_REAL(a_name) + `RANGE_PARAM_REAL(b_name), c_width); \
    `ADD_INTO_REAL(a_name, b_name, c_name)
`define ADD_REAL(a_name, b_name, c_name) \
    `ADD_REAL_GENERIC(a_name, b_name, c_name, `LONG_WIDTH_REAL)

`define DFF_INTO_REAL(d_name, q_name, rst_name, clk_name, cke_name, init_expr) \
    dff_real #( \
        `PASS_REAL(d, d_name), \
        `PASS_REAL(q, q_name), \
        .init(init_expr) \
    ) dff_real_``q_name``_i ( \
        .d(d_name), \
        .q(q_name), \
        .rst(rst_name), \
        .clk(clk_name), \
        .cke(cke_name) \
    )

module add_sub_real #(
    `DECL_REAL(a),
    `DECL_REAL(b),
    `DECL_REAL(c),
	parameter integer opcode=0
) (
    `INPUT_REAL(a),
    `INPUT_REAL(b),
    `OUTPUT_REAL(c)
);
`ifndef HARD_FLOAT
    `COPY_FORMAT_REAL(c, a_aligned);
    `COPY_FORMAT_REAL(c, b_aligned);

    `ASSIGN_REAL(a, a_aligned);
    `ASSIGN_REAL(b, b_aligned);

    generate
        if          (opcode == `ADD_OPCODE_REAL) begin
            assign c = a_aligned + b_aligned;
        end else if (opcode == `SUB_OPCODE_REAL) begin
            assign c = a_aligned - b_aligned;
        end else begin
            initial begin
                $display("ERROR: Invalid opcode.");
                $finish;
            end
        end
    endgenerate
`else
    logic subOp;
    assign subOp = (opcode == `SUB_OPCODE_REAL) ? 1'b1 : 1'b0;

    addRecFN #(
        .expWidth(`HARD_FLOAT_EXP_WIDTH),
        .sigWidth(`HARD_FLOAT_SIG_WIDTH)
    ) addRecFN_i (
        .control(`HARD_FLOAT_CONTROL),
        .subOp(subOp),
        .a(a),
        .b(b),
        .roundingMode(`HARD_FLOAT_ROUNDING),
        .out(c),
        .exceptionFlags()
    );
`endif
endmodule

module assign_real #(
    `DECL_REAL(in),
    `DECL_REAL(out)
) (
    `INPUT_REAL(in),
    `OUTPUT_REAL(out)
);
    `ifdef FLOAT_REAL
        assign out = in;
    `elsif HARD_FLOAT
        assign out = in;
    `else
        localparam integer lshift = `EXPONENT_PARAM_REAL(in) - `EXPONENT_PARAM_REAL(out);

        generate
            if (lshift >= 0) begin
                assign out = in <<< (+lshift);
            end else begin
                assign out = in >>> (-lshift);
            end
        endgenerate
    `endif
endmodule

module dff_real #(
    `DECL_REAL(d),
    `DECL_REAL(q),
	parameter real init=0
) (
    `INPUT_REAL(d),
    `OUTPUT_REAL(q),
    input wire logic rst,
    input wire logic clk,
    input wire logic cke
);
    // "var" for memory is kept internal
    // so that all ports are "wire" type nets
    `COPY_FORMAT_REAL(q, q_mem);
    `ASSIGN_REAL(q_mem, q);

    // align input to output
    `COPY_FORMAT_REAL(q, d_aligned);
    `ASSIGN_REAL(d, d_aligned);

    // align initial value to output format
    `COPY_FORMAT_REAL(q, init_aligned);
    `ASSIGN_CONST_REAL(init, init_aligned);

    // main DFF logic
    always @(posedge clk) begin
        if (rst == 1'b1) begin
            q_mem <= init_aligned;
        end else if (cke == 1'b1) begin
            q_mem <= d_aligned;
        end else begin
            q_mem <= q;
        end
    end
endmodule

module mul_real #(
    `DECL_REAL(a),
    `DECL_REAL(b),
    `DECL_REAL(c)
) (
    `INPUT_REAL(a),
    `INPUT_REAL(b),
    `OUTPUT_REAL(c)
);
`ifndef HARD_FLOAT
    // create wire to hold product result
    `MAKE_FORMAT_REAL(
        prod,
        `RANGE_PARAM_REAL(a) * `RANGE_PARAM_REAL(b),
        `WIDTH_PARAM_REAL(a) + `WIDTH_PARAM_REAL(b),
       `EXPONENT_PARAM_REAL(a) + `EXPONENT_PARAM_REAL(b)
    );

    // compute product
    assign prod = a * b;

    // assign result to output (which will left/right shift if necessary)
    `ASSIGN_REAL(prod, c);
`else
    mulRecFN #(
        .expWidth(`HARD_FLOAT_EXP_WIDTH),
        .sigWidth(`HARD_FLOAT_SIG_WIDTH)
    ) mulRecFN_i (
        .control(`HARD_FLOAT_CONTROL),
        .a(a),
        .b(b),
        .roundingMode(`HARD_FLOAT_ROUNDING),
        .out(c),
        .exceptionFlags()
    );
`endif
endmodule


`default_nettype none

module WalkEnAstable555 #(
    `DECL_REAL(walk_en),
    `DECL_REAL(square_wave),
    `DECL_REAL(vcc),
    `DECL_REAL(v_control)
) (
    input wire logic rst,
    input wire logic clk,
    input wire logic cke,
    `INPUT_REAL(walk_en),
    `INPUT_REAL(square_wave),
    `INPUT_REAL(vcc),
    `OUTPUT_REAL(v_control)
);
    // Declaring internal variables.
    `MAKE_REAL(tmp_circ_4, `RANGE_PARAM_REAL(v_control));
    // Assign signal: tmp_circ_4
   //  `MUL_CONST_REAL(0.9988949512946891, tmp_circ_4, tmp0);
   //  `MUL_CONST_REAL(0.00021549311726031938, square_wave, tmp1);
   //  `MUL_CONST_REAL(0.0006309638473382152, vcc, tmp2);
   //  `MUL_CONST_REAL(0.0002585917407123833, walk_en, tmp3);
    `MUL_CONST_REAL(0.9977899025, tmp_circ_4, tmp0);
    `MUL_CONST_REAL(0.000430986, square_wave, tmp1);
    `MUL_CONST_REAL(0.001261927, vcc, tmp2);
    `MUL_CONST_REAL(0.000517183, walk_en, tmp3);
    `ADD_REAL(tmp0, tmp1, tmp4);
    `ADD_REAL(tmp2, tmp3, tmp5);
    `ADD_REAL(tmp4, tmp5, tmp6);
    `DFF_INTO_REAL(tmp6, tmp_circ_4, rst, clk, cke, 0);
    // Assign signal: v_control
    `ASSIGN_REAL(tmp_circ_4, v_control);
endmodule

`default_nettype wire
