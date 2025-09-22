module sa_compute
#(
    parameter ADD_DATAWIDTH,
    parameter MUL_DATAWIDTH,
    parameter NUM_ROWS,
    parameter NUM_COLS
)(
    // clk, rst
    input logic clk,
    input logic rst_n,

    // mode
    input logic i_mode,

    // Is this a better idea than having an external accumulator block?
    // load psum (mux control)
    // 0: col_inter[0][n] <- i_weights
    // 1: col_inter[0][n] <- i_psum
    input logic i_load_psum,

    // inputs
    // i_act buffer & weight buffer
    input logic [MUL_DATAWIDTH-1 : 0] i_act     [NUM_ROWS],
    input logic [MUL_DATAWIDTH-1 : 0] i_weight  [NUM_COLS],

    // intermediate partial sums buffer
    input logic [ADD_DATAWIDTH-1 : 0] i_psum    [NUM_COLS],

    // output partial sums buffer
    output logic [ADD_DATAWIDTH-1 : 0] o_psum   [NUM_COLS]
);

    // --------------------------------------- //
    // ------ PE array interconnections ------ //
    // --------------------------------------- //
    // Row-wise (horizontal) interconnection
    // Dimensions: (NUM_ROWS)x(NUM_COLS+1)
    // Note: NUM_COLS + 1 is needed for the output of the right-most PEs
    //       which gets connected to an o_act signal used with DEBUG ifdef
    logic [MUL_DATAWIDTH-1 : 0] row_inter [NUM_ROWS][NUM_COLS+1]; // row_inter[j][i]

    // Column-wise (vertical) interconnection
    // Dimensions: (NUM_ROWS+1)x(NUM_COLS)
    // Note: NUM_ROWS + 1 is needed for the output of the bottom-most PEs
    //       which is connected to o_psum
    logic [ADD_DATAWIDTH-1 : 0] col_inter [NUM_ROWS+1][NUM_COLS]; // column_inter[j][i]

    // ---------------------------------------- //
    // ------ PE Array Generate For-Loop ------ //
    // ---------------------------------------- //
    // j = row coordinate       (y)
    // i = column coordinate    (x)
    genvar i, j; // (x,y) = (i,j)
    generate
        for (j = 0; j < NUM_ROWS; j += 1) begin : row_coord
            for (i = 0; i < NUM_COLS; i += 1) begin : col_coord
                sa_pe #(
                    .ADD_DATAWIDTH(ADD_DATAWIDTH),
                    .MUL_DATAWIDTH(MUL_DATAWIDTH)
                ) sa_pe_inst (
                    // clk, rst, mode
                    .clk(clk),
                    .rst_n(rst_n),
                    .i_mode(i_mode),
                    // inputs
                    .i_act(row_inter[j][i]),
                    .i_weight(col_inter[j][i]),
                    .i_psum(col_inter[j][i]),
                    // outputs
                    .o_act(row_inter[j][i+1]),
                    .o_weight_psum(col_inter[j+1][i])
                );
            end
        end
    endgenerate

    // -------------------------------------- //
    // ----- Input / Output Assignments ----- //
    // -------------------------------------- //
    // Input Weights and Psums
    genvar n;
    generate
        for (n = 0; n < NUM_COLS; n += 1) begin : gen_i_weight_psum
            assign col_inter[0][n] = i_load_psum ? i_psum[n] : i_weight[n];
        end
    endgenerate

    // Input Act
    generate
        for (n = 0; n < NUM_ROWS; n += 1) begin : gen_i_act
            // For WS Systolic, iActs need to be shifted, the compute array expects
            // a shifted set of i_act i.e. it will take the entire iActs word and pass
            // it into the array. 
            // Shifting MUST be handled by the level above
            assign row_inter[n][0] = i_act[n];
        end
    endgenerate

    // Output sum (total or partial)
    generate
        for (n = 0; n < NUM_COLS; n += 1) begin : gen_o_psum
            // last row of column interconnect
            assign o_psum[n] = col_inter[NUM_ROWS][n];
        end
    endgenerate

    // ------------------------- //
    // ----- DEBUG Signals ----- //
    // ------------------------- //
    `ifdef DEBUG
        // Output activations for visualization of iAct propagation through array
        logic [MUL_DATAWIDTH-1 : 0] o_act [NUM_ROWS];
        generate
            for (n = 0; n < NUM_ROWS; n += 1) begin : gen_o_act
                assign o_act[n] = row_inter[n][NUM_COLS];
            end
        endgenerate
    `endif

    // TODO: Add functional coverage :)
    //  - interconnect coverage
endmodule