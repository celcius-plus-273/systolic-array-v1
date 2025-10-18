module sa_matmul
#(
    // data params
    parameter WIDTH,
    // array params
    parameter ROW,
    parameter COL,
    // memory params
    parameter W_SIZE,
    parameter I_SIZE,
    parameter O_SIZE
) (
    //--- Mat Mul Port ---//
    // clk, reset, control signals
    input  logic                          clk_i,            // clock signal
    input  logic                          rstn_i,           // active low reset signal
    input  logic                          start_i,          // active high start calculation, must reset back to 0 first to start a new calculation
    // input  data_config_struct             data_config_i,    // test controls
    // output buffer memory
    output  logic                         ob_mem_cenb_o,    // memory enable, active low
    output  logic                         ob_mem_wenb_o,    // write enable, active low
    output  logic [$clog2(O_SIZE)-1:0]    ob_mem_addr_o,    // address
    output  logic [COL-1:0][WIDTH-1:0]    ob_mem_data_o,    // input data
    input   logic [COL-1:0][WIDTH-1:0]    ob_mem_data_i,    // output data
    // input buffer memory
    output  logic                         ib_mem_cenb_o,    // memory enable, active low
    output  logic                         ib_mem_wenb_o,    // write enable, active low
    output  logic [$clog2(I_SIZE)-1:0]    ib_mem_addr_o,    // address
    input   logic [ROW-1:0][WIDTH-1:0]    ib_mem_data_i,    // input data
    // weights buffer memory
    output  logic                         wb_mem_cenb_o,    // memory enable, active low
    output  logic                         wb_mem_wenb_o,    // write enable, active low
    output  logic [$clog2(W_SIZE)-1:0]    wb_mem_addr_o,    // address
    input   logic [COL-1:0][WIDTH-1:0]    wb_mem_data_i,    // input data
    // partial sum buffer memory
    output  logic                         ps_mem_cenb_o,    // memory enable, active low
    output  logic                         ps_mem_wenb_o,    // write enable, active low
    output  logic [$clog2(W_SIZE)-1:0]    ps_mem_addr_o,    // address
    output  logic [COL-1:0][WIDTH-1:0]    ps_mem_data_o,    // input data
    input   logic [COL-1:0][WIDTH-1:0]    ps_mem_data_i,    // output data
    // external mode
    // input  logic                          ext_en_i,         // external mode enable, acitve high
    // input  external_inputs_struct         ext_inputs_i,     // external inputs
    // output logic [COL-1:0][WIDTH-1:0]     ext_result_o,     // external outputs
    // output logic                          ext_valid_o,      // external valid
    // output done
    output logic                          done_o            // data controls
);

    //---------------------------------//
    //--- Systolic Array Controller ---//
    //---------------------------------//
    logic ctrl_mode, ctrl_load_psum;
    sa_control #(
        .INPUT_WIDTH(ROW*WIDTH),
        .INPUT_HEIGHT(I_SIZE),
        .WEIGHT_WIDTH(COL*WIDTH),
        .WEIGHT_HEIGHT(W_SIZE),
        .OUTPUT_WIDTH(COL*WIDTH),
        .OUTPUT_HEIGHT(O_SIZE),

        .NUM_ROWS(ROW),
        .NUM_COLS(COL)
    ) sys_array_ctrl (
        .clk(clk_i),
        .rst_n(rstn_i),

        // control signals
        // .i_en(),    // not connected
        .i_start(start_i),
        .o_done(done_o),

        // systolic array control signals
        .o_mode(ctrl_mode),
        .o_load_psum(ctrl_load_psum),

        // input activation buffer
        .r_input_cenb(ib_mem_cenb_o),
        .r_input_wenb(ib_mem_wenb_o),
        .r_input_addr(ib_mem_addr_o),

        // weight buffer
        .r_weight_cenb(wb_mem_cenb_o),
        .r_weight_wenb(wb_mem_wenb_o),
        .r_weight_addr(wb_mem_addr_o),

        // output activation buffer
        .w_output_cenb(ob_mem_cenb_o),
        .w_output_wenb(ob_mem_wenb_o),
        .w_output_addr(ob_mem_addr_o)
    );

    //----------------------------------//
    //--- Systolic Computation Array ---//
    //----------------------------------//
    sa_compute #(
        .MUL_DATAWIDTH(WIDTH),
        .ADD_DATAWIDTH(WIDTH),
        .NUM_ROWS(ROW),
        .NUM_COLS(COL)
    ) sys_array (
        .clk(clk_i),
        .rst_n(rstn_i),

        // control signals (coming from sa_control)
        .i_mode(ctrl_mode),
        .i_load_psum(ctrl_load_psum),

        // input act port
        .i_act(ib_mem_data_i),
        // weight port
        .i_weight(wb_mem_data_i),
        // input psum port        
        .i_psum('0),
        // output act port
        .o_psum(ob_mem_data_o)
    );

endmodule