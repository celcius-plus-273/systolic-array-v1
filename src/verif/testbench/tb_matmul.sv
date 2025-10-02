module tb_matmul;
// Testbench parameters
localparam CLK_PERIOD   = 10;   // it works for now
localparam RANGE        = 8;    // range for random values

// Matrix dimensions
//  (M,K) * (K,N) = (M,N)
localparam M            = 4; // streaming dimension (larger is better)
localparam K            = 4; // systolic height (num rows)
localparam N            = 4; // systolic width (num cols)

// Design parameters
localparam ADD_DATAWIDTH    = 8;
localparam MUL_DATAWIDTH    = 8;
localparam NUM_ROWS         = K;    // for now we will make it match to MatMul
localparam NUM_COLS         = N;

// Global signals
bit clk;
bit rst_n;

// clkgen
always #(CLK_PERIOD/2) clk=~clk;

// DUT signals
logic i_start;
logic o_done;

// DUT Instance
sa_matmul #(
    .ADD_DATAWIDTH(ADD_DATAWIDTH),
    .MUL_DATAWIDTH(MUL_DATAWIDTH),
    .NUM_ROWS(NUM_ROWS),
    .NUM_COLS(NUM_COLS)
) dut0 (.*);

// Test variables
int cycle = 0;

initial begin
    string dumpfile = "matmul";
    `ifdef VCS
        // FSDB Dump (Waveform)
        $fsdbDumpfile({dumpfile,".fsdb"});
        $fsdbDumpvars(0, dut0);
        $fsdbDumpon;
    `else
        $dumpfile({dumpfile,".fsdb"});
        $dumpvars(0, dut0);
    `endif
end

initial begin
    // reset signals
    reset_signals();

    // run sanity tests
    sanity_weight_pre_load();

    repeat(100) @(posedge clk);

    // exit sim
    $finish;
end

always @(posedge clk) begin
    cycle += 1;
end

// Monitor FSM of design :)
always @(negedge clk) begin
    $display("========== CYCLE: %0d ===========", cycle);
    $display("STATE = %0s", dut0.sys_array_ctrl.curr_state);
    $display("COUNT_R = %0d", dut0.sys_array_ctrl.count_r);
end

// ------------------------------------------------ //
//--------- General Systolic Functions ------------ //
// ------------------------------------------------ //
int i, j, n; // for loops

function print_PE(int i, int j);
    $display("|----------------------------------|") ;
    $display("| PE[%0d][%0d]", j, i);
    $display("| mode: %0s", dut0.sys_array.systolic_mode[j][i]);
    $display("| Input Act: %0d", dut0.sys_array.systolic_inputs[j][i]);
    $display("| Input Weight: %0d", dut0.sys_array.systolic_input_weights[j][i]);
    $display("| Input PSUM: %0d", dut0.sys_array.systolic_psums[j][i]);
    $display("| Computing... (%0d) * (%0d) + %0d",
        dut0.sys_array.systolic_inputs[j][i],
        dut0.sys_array.systolic_weights[j][i],
        dut0.sys_array.systolic_psums[j][i],
    );
    $display("| Output Weight/PSUM: %0d", dut0.sys_array.systolic_outputs[j][i]);
    $display("|----------------------------------|");
endfunction

// -------------------------------------------- //
//--------- General Systolic Tasks ------------ //
// -------------------------------------------- //
// reset signals / init signals
task automatic reset_signals();
    // toggle reset
    rst_n = 1'b0;

    // reset control signals
    i_start = 1'b0;

    // wait two cycles
    repeat(2) @(posedge clk);

    // de-assert reset
    rst_n = 1'b1;
endtask

task automatic start_matmul();
    // assert start
    i_start = 1'b1;
endtask

// Sanity test for weight pre-load
//  - Create random weights
//  - Assert if they match :)
// expose all of the weights (this is needed for generate loop XMR)
task automatic sanity_weight_pre_load();
    // reset
    reset_signals();

    // fill-up weight buffer with random values
    // generate_random_weights();

    // pre-load weights
    // load_weights();
    start_matmul();

    // // weight_r is non-blocking, if we try to sample it at the end of (posedge clk)
    // // the LHS hasn't updated yet. Instead, sample at negedge or some fixed delay (e.g. #1)
    // @(negedge clk);

    // // now check that each PE has the right weight
    // for (j = 0; j < NUM_ROWS; j += 1) begin
    //     for (i = 0; i < NUM_COLS; i += 1) begin
    //         assert(weight_buffer[j][i] == dut0.systolic_weights[j][i]);
    //     end
    // end

    // $display("Buffer Weights:");
    // print_weights(weight_buffer);

    // $display("Systolic Weights:");
    // print_weights(dut0.systolic_weights);
endtask

// Sanity test for i_act forwarding
//  - generate random i_act
//  - set array to compute mode (DEBUG = 1)
//  - push i_act
//  - check o_act
// task automatic sanity_act_forward();
//     // reset
//     reset_signals();

//     // generate random activations
//     generate_random_inputs();

//     // sync with posedge
//     @(posedge clk);
//     // set array to compute
//     i_mode = 1'b1;

//     // reset count
//     count = 0;

//     for (i = 0; i < I_ACT_WIDTH + O_ACT_WIDTH - 1; i += 1) begin
//         // pass in i_act
//         i_act = input_buffer[i];

//         @(posedge clk);
//         count += 1;

//         // need to sample at negedge bc of non-blocking assignment
//         if (count >= NUM_COLS) begin
//             @(negedge clk);
//             // assert o_act == i_act
//             assert(dut0.o_act == input_buffer[out_count])

//             // debug print
//             print_act_vector(dut0.o_act);
//             $write(" =? ");
//             print_act_vector(input_buffer[out_count]);
//             $write("\n");

//             // increment output counter
//             out_count += 1;
//         end
//     end
// endtask

// // Functional test (First Smoke test)
// //  - generate random data on i_act buffer
// //  - generate random data on i_weight buffer
// //  - pre-load weight buffer (i_mode = 0)
// //  - stream activations (i_mode = 1)
// //  - collect outputs
// //      - wait NUM_COLS cycles
// //      - write result to output buffer until 
// task automatic smoke_random_mult;
//     // reset
//     reset_signals();

//     // generate random activations and weights
//     generate_random_inputs();
//     generate_random_weights();

//     // pre-load weights
//     load_weights();

//     // stream i_act and capture o_act
//     run_compute();

//     // verify output (for now we just print)
//     print_inputs(input_buffer);
//     $display("Systolic Weights:");
//     print_weights(dut0.systolic_weights);
//     print_outputs(output_buffer);
// endtask

endmodule
`default_nettype wire