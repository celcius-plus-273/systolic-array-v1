`ifndef __MATRIX_MULT_PKG__
`define __MATRIX_MULT_PKG__

package matrix_mult_pkg;

localparam WIDTH    = 8;
localparam ROW      = 4;
localparam COL      = 4;
localparam W_SIZE   = 256;
localparam I_SIZE   = 256;
localparam O_SIZE   = 256;

localparam INPUT_DATA_WIDTH = WIDTH * ROW;
localparam WEIGHT_DATA_WIDTH = WIDTH * COL;

localparam DRIVER_WIDTH  = WIDTH * ( ROW + COL );

typedef struct packed{
    logic [$clog2(ROW)-1:0]      w_rows;            // weights matrix rows
    logic [$clog2(COL)-1:0]      w_cols;            // weights matrix columns
    logic [$clog2(I_SIZE)-1:0]   i_rows;            // inputs matrix rows
    logic [$clog2(W_SIZE)-1:0]   w_offset;          // weights memory offset
    logic [$clog2(I_SIZE)-1:0]   i_offset;          // inputs memory offset
    logic [$clog2(O_SIZE)-1:0]   psum_offset;       // partial sums memory offset
    logic [$clog2(O_SIZE)-1:0]   o_offset_w;        // outputs memory offset
    logic                        accum_en;          // accumulation enabled
} data_config_struct;

typedef struct packed{
    logic [2:0]                  bypass;            // bypasses
    logic [1:0]                  mode;              // modes
    logic                        driver_valid;      // driver valid bit
    logic [DRIVER_WIDTH-1:0]     driver_stop_code;  // driver stop code
} test_config_struct;

typedef struct packed{
    logic                        ext_weight_en;     // external weights push enable
    logic [ROW-1:0][WIDTH-1:0]   ext_input;         // external inputs
    logic                        ext_valid;         // external valid input
    logic [COL-1:0][WIDTH-1:0]   ext_weight;        // external weights
    logic [COL-1:0][WIDTH-1:0]   ext_psum;          // external partial sums
} external_inputs_struct;

endpackage

import matrix_mult_pkg::*;

`endif