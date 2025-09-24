module sa_matmul
#(
    // data params
    parameter ADD_DATAWIDTH,
    parameter MUL_DATAWIDTH,
    // array params
    parameter NUM_ROWS,
    parameter NUM_COLS
) (
    // clk, rst
    input logic clk,
    input logic rst_n,

    // start, done
    input logic i_start,
    output logic o_done

    // data config (check sa_pkg) (won't use for now)
);
    // Input, Weight, Output Memory Instances
    
    // Control Instance

    // Compute Instance
endmodule