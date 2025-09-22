module tb_comp_array_only;
// Testbench parameters
localparam CLK_PERIOD = 10; // it works for now

// Design parameters
localparam ADD_DATAWIDTH    = 8;
localparam MUL_DATAWIDTH    = 8;
localparam NUM_COLS         = 4;
localparam NUM_ROWS         = 4;

// Global signals
bit clk;
bit rst_n;

// clkgen
always #(CLK_PERIOD/2) clk=~clk;

// DUT signals
logic i_mode;         // weight pre-load | compute
logic i_load_psum;    // psum or weight
logic [MUL_DATAWIDTH-1:0] i_act     [NUM_ROWS]; 
logic [MUL_DATAWIDTH-1:0] i_weight  [NUM_COLS]; 
logic [ADD_DATAWIDTH-1:0] i_psum    [NUM_COLS]; 
logic [ADD_DATAWIDTH-1:0] o_psum    [NUM_COLS]; 

// DUT Instance
sa_compute #(
    .ADD_DATAWIDTH(ADD_DATAWIDTH),
    .MUL_DATAWIDTH(MUL_DATAWIDTH),
    .NUM_ROWS(NUM_ROWS),
    .NUM_COLS(NUM_COLS)
) dut0 (.*);

// Test variables
// weight buffer (NUM_ROWS)x(NUM_COLS)
logic [MUL_DATAWIDTH-1:0] weight_buffer [NUM_ROWS][NUM_COLS]; 

initial begin
    string dumpfile = "comp_array_only";
    `ifdef VCS
        // FSDB Dump (Waveform)
        $fsdbDumpfile("%0s.fsdb", dumpfile);
        $fsdbDumpvars(0, dut0);
        $fsdbDumpon;
    `else
        $dumpfile("%0s.fsdb", dumpfile);
        $dumpvars(0, dut0);
    `endif
end

initial begin
    // reset signals
    reset_signals();

    // run sanity tests
    check_weight_pre_load();

    // exit sim
    $finish;
end

// define some tasks
int i; // for loops
int j; // for loops
task reset_signals();
    // toggle reset
    rst_n = 1'b0;

    // reset control signals
    i_mode = 1'b0;      // default is weight pre-load
    i_load_psum = 1'b0; // default is weight on north port

    // clear row-wise IO
    for (i = 0; i < NUM_ROWS; i += 1) begin
        i_act[i] = '0;
    end

    // clear column-wise IO
    for (i = 0; i < NUM_COLS; i += 1) begin
        i_weight[i] = '0;
        i_psum[i] = '0;
        o_psum[i] = '0;
    end

    // wait two cycles
    repeat(2) @(posedge clk);

    // de-assert reset
    rst_n = 1'b1;
endtask

// Sanity test for weight pre-load
//  - Create random weights
//  - Shift them into array in pre-load mode
//  - Assert if they match :)
task check_weight_pre_load();

    // generate random weight values
    for (j = 0; j < NUM_ROWS; j += 1) begin
        for (i = 0; i < NUM_COLS; i += 1) begin
            weight_buffer[j][i] = ($random % 32) + 1; // random value from [1, 32]
        end
    end

    // set array to pre-load
    i_mode = 1'b0;
    // connect north port to i_weight
    i_load_psum = 1'b0;

    // now load the values from the random weight buffer
    for (j = 0; j < NUM_ROWS; j += 1) begin
        // load from last row to first
        i_weight = weight_buffer[NUM_ROWS - 1 - j];

        // toggle clock
        // - weights should move downwards
        @(posedge clk);
    end
    
    // now check that each PE has the right weight
    for (j = 0; j < NUM_ROWS; j += 1) begin
        for (i = 0; i < NUM_COLS; i += 1) begin
            assert(weight_buffer[j][i] == dut0.row_coord[j].col_coord[i].sa_pe_inst.weight_r);
        end
    end
    
endtask
endmodule
`default_nettype wire