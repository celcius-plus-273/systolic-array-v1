//
// simple MAC implementation
//  psum_next = (act * weight) + psum_prev
module sa_mac_simple
#(
    // no default parameter values (MUST BE DEFINED)
    parameter ADD_DATAWIDTH,
    parameter MUL_DATAWIDTH
)(
    // Inputs
     input logic signed [MUL_DATAWIDTH-1 : 0] i_act
    ,input logic signed [MUL_DATAWIDTH-1 : 0] i_weight
    ,input logic signed [ADD_DATAWIDTH-1 : 0] i_psum

    // Output
    ,output logic signed [ADD_DATAWIDTH-1 : 0] o_psum
);
    // -- localparams -- //
    // 8 bit example
    //  MAX_MULT = (2 ** 7) - 1 = 127
    //  MIN_MULT = -1 * (2 ** 7) = -128
    localparam MAX_MULT = 2 ** (MUL_DATAWIDTH - 1) - 1;
    localparam MIN_MULT = -1 * (2 ** (MUL_DATAWIDTH - 1));    
    localparam MAX_ADD = 2 ** (ADD_DATAWIDTH - 1) - 1;
    localparam MIN_ADD = -1 * (2 ** (ADD_DATAWIDTH - 1));

    // -- internal wires -- //
    logic signed [(2*MUL_DATAWIDTH)-1   : 0] mult_result;
    logic signed [MUL_DATAWIDTH-1       : 0] mult_result_sat;
    logic signed [(ADD_DATAWIDTH-1) + 1 : 0] add_result;
    logic signed [ADD_DATAWIDTH-1       : 0] add_result_sat;

    // BASIC FULLY COMBINATIONAL MAC
    always_comb begin : saturation_mac
        // multiply
        mult_result = i_act * i_weight;
        
        // saturate
        if (mult_result > MAX_MULT)
            mult_result_sat = MAX_MULT;
        else if (mult_result < MIN_MULT)
            mult_result_sat = MIN_MULT;
        else
            mult_result_sat = mult_result;

        // add
        add_result = mult_result + i_psum;

        // saturate
        if (add_result > MAX_ADD) 
            add_result_sat = MAX_ADD;
        else if (add_result < MIN_ADD)
            add_result_sat = MIN_ADD;
        else
            add_result_sat = add_result;
    end

    assign o_psum = add_result_sat;

    // TODO: Handle multiplication and addition overflow
    //    - one idea is to detect overflow by doing a reduction OR
    //      operation
    //    - output mux to select from '1 and psum_result
    //

endmodule
