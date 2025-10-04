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
    //-- localparams --//
    localparam MEM_ROWS     = 8;
    localparam INPUT_WIDTH  = MUL_DATAWIDTH * NUM_ROWS;
    localparam WEIGHT_WIDTH = MUL_DATAWIDTH * NUM_COLS;
    localparam OUTPUT_WIDTH = ADD_DATAWIDTH * NUM_COLS;

    //------------------//
    //-- Input Memory --//
    //------------------//
    logic                           r_input_cenb;
    logic                           r_input_wenb;
    logic [$clog2(MEM_ROWS)-1 : 0]  r_input_addr;
    logic [INPUT_WIDTH-1 : 0]       r_input_data;
    mem_simple #(
        .NUM_ENTRIES(MEM_ROWS),
        .DATA_WIDTH(INPUT_WIDTH)
    ) input_mem (
        .clk(clk),
        .rst_n(rst_n),
        // cenb & wenb
        .i_cenb(r_input_cenb),
        .i_wenb(r_input_wenb),
        // addr & data
        .i_addr(r_input_addr),  // addr port
        .i_data(),              // not connected
        .o_data(r_input_data)   // data port
    );
    
    //-------------------//
    //-- Weight Memory --//
    //-------------------//
    logic                           r_weight_cenb;
    logic                           r_weight_wenb;
    logic [$clog2(MEM_ROWS)-1 : 0]  r_weight_addr;
    logic [WEIGHT_WIDTH-1 : 0]      r_weight_data;
    mem_simple #(
        .NUM_ENTRIES(MEM_ROWS),
        .DATA_WIDTH(WEIGHT_WIDTH)
    ) weight_mem (
        .clk(clk),
        .rst_n(rst_n),
        // cenb & wenb
        .i_cenb(r_weight_cenb),
        .i_wenb(r_weight_wenb),
        // addr & data
        .i_addr(r_weight_addr), // addr port
        .i_data(),              // not connected
        .o_data(r_weight_data)  // data port
    );
    
    //-------------------//
    //-- Output Memory --//
    //-------------------//
    logic                           w_output_cenb;
    logic                           w_output_wenb;
    logic [$clog2(MEM_ROWS)-1 : 0]  w_output_addr;
    logic [OUTPUT_WIDTH-1 : 0]      w_output_data;
    mem_simple #(
        .NUM_ENTRIES(MEM_ROWS),
        .DATA_WIDTH(OUTPUT_WIDTH)
    ) output_mem (
        .clk(clk),
        .rst_n(rst_n),
        // cenb & wenb
        .i_cenb(w_output_cenb),
        .i_wenb(w_output_wenb),
        // addr & data
        .i_addr(w_output_addr), // addr port
        .i_data(w_output_data), // data port
        .o_data()               // not connected
    );
    
    //---------------------------------//
    //--- Systolic Array Controller ---//
    //---------------------------------//
    logic ctrl_mode, ctrl_load_psum;
    sa_control #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .INPUT_HEIGHT(MEM_ROWS),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .WEIGHT_HEIGHT(MEM_ROWS),
        .OUTPUT_WIDTH(OUTPUT_WIDTH),
        .OUTPUT_HEIGHT(MEM_ROWS),

        .NUM_ROWS(NUM_ROWS),
        .NUM_COLS(NUM_COLS)
    ) sys_array_ctrl (
        .clk(clk),
        .rst_n(rst_n),

        // control signals
        // .i_en(),    // not connected
        .i_start(i_start),
        .o_done(o_done),

        // systolic array control signals
        .o_mode(ctrl_mode),
        .o_load_psum(ctrl_load_psum),

        // mem interface uses same name as port
        .*
    );

    //----------------------------------//
    //--- Systolic Computation Array ---//
    //----------------------------------//
    logic signed [MUL_DATAWIDTH-1 : 0] i_act     [NUM_ROWS];
    logic signed [MUL_DATAWIDTH-1 : 0] i_weight  [NUM_COLS];
    logic signed [ADD_DATAWIDTH-1 : 0] o_act     [NUM_COLS];
    logic signed [ADD_DATAWIDTH-1 : 0] i_psum    [NUM_COLS];
    sa_compute #(
        .MUL_DATAWIDTH(MUL_DATAWIDTH),
        .ADD_DATAWIDTH(ADD_DATAWIDTH),
        .NUM_ROWS(NUM_ROWS),
        .NUM_COLS(NUM_COLS)
    ) sys_array (
        .clk(clk),
        .rst_n(rst_n),

        // control signals (coming from sa_control)
        .i_mode(ctrl_mode),
        .i_load_psum(ctrl_load_psum),

        // input act port
        .i_act(i_act),
        // weight port
        .i_weight(i_weight),
        // input psum port        
        .i_psum(i_psum),
        // output act port
        .o_psum(o_act)
    );
    // generate loop variable (genvar)
    genvar i;
    generate
        // input activation connections
        for (i = 0; i < NUM_ROWS; i += 1) begin
            assign i_act[i] = r_input_data[((MUL_DATAWIDTH*(NUM_ROWS - i)) - 1) -: MUL_DATAWIDTH];
        end
        // weight connections
        for (i = 0; i < NUM_COLS; i += 1) begin
            assign i_weight[i] = r_weight_data[((MUL_DATAWIDTH*(NUM_COLS - i)) - 1) -: MUL_DATAWIDTH];
        end
        // output activation connections
        for (i = 0; i < NUM_COLS; i += 1) begin
            assign w_output_data[((ADD_DATAWIDTH*(NUM_COLS - i)) - 1) -: ADD_DATAWIDTH] = o_act[i];
        end
        // fix i_psum to 0
        for (i = 0; i < NUM_COLS; i += 1) begin
            assign i_psum[i] = '0;
        end
    endgenerate

endmodule