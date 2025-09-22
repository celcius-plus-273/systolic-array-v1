module tb_comp_array_only;
// Testbench parameters
localparam CLK_PERIOD   = 10; // it works for now
localparam NUM_ACT      = 10;

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
logic [MUL_DATAWIDTH-1:0] weight_buffer     [NUM_ROWS][NUM_COLS]; 
logic [MUL_DATAWIDTH-1:0] systolic_weight   [NUM_ROWS][NUM_COLS]; 
// expose all of the weights
genvar x, y;
generate
    for (y = 0; y < NUM_ROWS; y += 1) begin
        for (x = 0; x < NUM_COLS; x += 1) begin
            assign systolic_weight[y][x] = dut0.row_coord[y].col_coord[x].sa_pe_inst.weight_r;
        end
    end
endgenerate
// act buffer
logic [MUL_DATAWIDTH-1:0] act_vec [NUM_ACT][NUM_ROWS]; 

initial begin
    string dumpfile = "comp_array_only";
    `ifdef VCS
        // FSDB Dump (Waveform)
        $fsdbDumpfile({dumpfile,".fsdb"});
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
    sanity_weight_pre_load();
    sanity_act_forward();

    // exit sim
    $finish;
end

// task variables
int i, j; // for loops

// reset signals / init signals
task automatic reset_signals();
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
    end

    // wait two cycles
    repeat(2) @(posedge clk);

    // de-assert reset
    rst_n = 1'b1;
endtask

// visualize weight buffers
function print_weights(logic [MUL_DATAWIDTH-1:0] weights [NUM_ROWS][NUM_COLS]);
    for (j = 0; j < NUM_ROWS; j += 1) begin
        $write("[");
        for (i = 0; i < NUM_COLS; i += 1) begin
            $write("%4d", weights[j][i]);
        end
        $write("]\n");
    end
endfunction

function print_act_vector(logic [MUL_DATAWIDTH-1:0] act [NUM_ROWS]);
    $write("[");
    for (j = 0; j < NUM_ROWS; j += 1) begin
        $write("%4d", act[j]);
    end
    $write("]");
endfunction

function print_o_psum_vector(logic [ADD_DATAWIDTH-1:0] o_psum [NUM_COLS]);
    $write("o_psum: [");
    for (i = 0; i < NUM_COLS; i += 1) begin
        $write("%4d", o_psum[i]);
    end
    $write("]\n");
endfunction

// Sanity test for weight pre-load
//  - Create random weights
//  - Shift them into array in pre-load mode
//  - Assert if they match :)
task automatic sanity_weight_pre_load();
    // generate random weight values
    for (j = 0; j < NUM_ROWS; j += 1) begin
        for (i = 0; i < NUM_COLS; i += 1) begin
            weight_buffer[j][i] = ({$random} % 2) + 1; // random value from [1, 32]
        end
    end

    // sync with posedge
    @(posedge clk);
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

    // weight_r is non-blocking, if we try to sample it at the end of (posedge clk)
    // the LHS hasn't updated yet. Instead, sample at negedge or some fixed delay (e.g. #1)
    @(negedge clk);

    // now check that each PE has the right weight
    for (j = 0; j < NUM_ROWS; j += 1) begin
        for (i = 0; i < NUM_COLS; i += 1) begin
            assert(weight_buffer[j][i] == systolic_weight[j][i]);
        end
    end

    $display("Buffer Weights:");
    print_weights(weight_buffer);

    $display("Systolic Weights:");
    print_weights(systolic_weight);
endtask

// Sanity test for i_act forwarding
//  - generate random i_act
//  - set array to compute mode (DEBUG = 1)
//  - push i_act
//  - check o_act
int count, out_count;
task automatic sanity_act_forward();
    // sync with posedge
    @(posedge clk);
    // set array to compute
    i_mode = 1'b1;

    // reset count
    count = 0;

    // generate NUM_ACT columns of activations
    for (i = 0; i < NUM_ACT + NUM_COLS - 1; i += 1) begin
        // generate random i_act
        if (count < NUM_ACT) begin
            for (j = 0; j < NUM_ROWS; j += 1) begin
                i_act[j] = ({$random} % 2) + 1;
            end
            act_vec[i] = i_act;
        end

        @(posedge clk);
        count += 1;

        // need to sample at negedge bc of non-blocking assignment
        if (count >= NUM_COLS) begin
            @(negedge clk);
            // assert o_act == i_act
            assert(dut0.o_act == act_vec[out_count])

            // debug print
            print_act_vector(dut0.o_act);
            $write(" =? ");
            print_act_vector(act_vec[out_count]);
            $write("\n");

            // increment output counter
            out_count += 1;
        end
    end
endtask

endmodule
`default_nettype wire