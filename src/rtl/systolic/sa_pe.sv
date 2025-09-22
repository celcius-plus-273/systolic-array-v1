// imports
// none

module sa_pe
#(
    // no default parameter values (MUST BE DEFINED)
    parameter ADD_DATAWIDTH,
    parameter MUL_DATAWIDTH
)(
    // clk, rst_n
    input logic clk,
    input logic rst_n,

    // enable PE
    // input logic i_en, // do we even need this signal

    // mode:
    //  0: weight pre-load
    //  1: compute
    input logic i_mode,

    // inputs: i_act, and i_weight, i_psum
    input logic [MUL_DATAWIDTH-1 : 0] i_act,
    input logic [MUL_DATAWIDTH-1 : 0] i_weight, // mul vs add datawidth...?
    input logic [ADD_DATAWIDTH-1 : 0] i_psum,

    // output
    output logic [MUL_DATAWIDTH-1 : 0] o_act, // pass activation to neighbor PE
    output logic [ADD_DATAWIDTH-1 : 0] o_weight_psum
);

    // weight register
    //  for now we will only hold a single weight on the PE
    logic [MUL_DATAWIDTH-1 : 0] weight_r;

    // mac output psum
    logic [ADD_DATAWIDTH-1: 0] mac_psum;

    // PE inputs
    always_ff @(posedge clk or negedge rst_n) begin : pe_in_ff
        if (!rst_n) begin
            weight_r <= '0;
        end
        else begin
            // update weight_r if we're in preload
            weight_r <= ~i_mode ? i_weight : weight_r;
        end
    end

    // PE outputs
    always_ff @(posedge clk or negedge rst_n) begin : pe_out_ff
        if (!rst_n) begin
            o_act <= '0;
            o_weight_psum <= '0;
        end
        else begin
            // if compute fw mac_psum
            // if preload fw i_weight
            o_weight_psum <= i_mode ? mac_psum : i_weight;

            // fw activation if in compute
            o_act <= i_mode ? i_act : o_act;
        end
    end

    // MAC instance
    //    for now only instantiate one MAC/PE
    //    this ratio can ba adjusted based on implementation
    sa_mac_simple #(
        .ADD_DATAWIDTH(ADD_DATAWIDTH),
        .MUL_DATAWIDTH(MUL_DATAWIDTH)
    ) sa_mac_0 (
        // mac inputs
        .i_act(i_act),
        .i_weight(weight_r),
        .i_psum(i_psum),

        // mac outputs
        .o_psum(mac_psum)
    );

    // TODO: add functional coverage
    //  - inputs
    //  - outputs
    //  - mode
endmodule
