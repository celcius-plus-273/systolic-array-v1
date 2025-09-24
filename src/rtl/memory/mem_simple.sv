module mem_simple
#(
    // size of memory
    parameter NUM_ENTIRES,
    parameter DATA_WIDTH,
    parameter WORD_SIZE,

    // localparams
    parameter ADDR_WIDTH = $clog2(NUM_ENTIRES)
) (
    // clk, rst
    input logic clk,
    input logic rst_n,

    // read ports
    input  logic                    r_en,
    input  logic [ADDR_WIDTH-1 : 0] r_addr,
    output logic [WORD_SIZE-1  : 0] r_data,

    // write ports
    input  logic                    w_en,
    input  logic [ADDR_WIDTH-1 : 0] w_addr,
    input  logic [WORD_SIZE-1  : 0] w_data
);

    // simple behavioral memory :)
    logic [WORD_SIZE-1 : 0] mem_array [NUM_ENTIRES];
    
endmodule