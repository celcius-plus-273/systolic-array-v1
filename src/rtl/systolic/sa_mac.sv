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
     input logic [MUL_DATAWIDTH-1 : 0] i_act
    ,input logic [MUL_DATAWIDTH-1 : 0] i_weight
    ,input logic [ADD_DATAWIDTH-1 : 0] i_psum

    // Output
    ,output logic [ADD_DATAWIDTH-1 : 0] o_psum
);

    // BASIC FULLY COMBINATIONAL MAC
    assign o_psum = (i_act * i_weight) + i_psum;

    // TODO: Handle multiplication and addition overflow
    //    - one idea is to detect overflow by doing a reduction OR
    //      operation
    //    - output mux to select from '1 and psum_result
    //

endmodule
