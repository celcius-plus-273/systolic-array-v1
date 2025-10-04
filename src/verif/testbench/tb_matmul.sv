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
bit count_en;

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
    // sanity_weight_pre_load();

    smoke_random_mult();

    // exit sim
    $finish;
end

always @(posedge clk) begin
    if (count_en) cycle += 1;
end

// Monitor FSM of design :)
always @(negedge clk) begin
    $display("========== CYCLE: %0d ===========", cycle);
    $display("STATE = %0s", dut0.sys_array_ctrl.curr_state);
    $display("COUNT_R = %0d", dut0.sys_array_ctrl.count_r);

    print_PE(0, 0);
    print_PE(1, 0);
    print_PE(2, 0);
    print_PE(3, 0);
    print_PE(3, 1);
    print_PE(3, 2);
    print_PE(3, 3);
end

// ------------------------------------------------ //
//--------- General Systolic Functions ------------ //
// ------------------------------------------------ //
int i, j, n; // for loops

// Print PE: shows what a specific PE is computing 
function print_PE(int j, int i);
    $display("|----------------------------------|") ;
    $display("| PE[%0d][%0d]", j, i);
    // $display("| mode: %0b", dut0.sys_array.systolic_mode[j][i]);
    // $display("| Input Act: %0d", dut0.sys_array.systolic_inputs[j][i]);
    // $display("| Input Weight: %0d", dut0.sys_array.systolic_input_weights[j][i]);
    // $display("| Input PSUM: %0d", dut0.sys_array.systolic_psums[j][i]);
    $display("| Computing... (%0d) * (%0d) + %0d",
        dut0.sys_array.systolic_inputs[j][i],
        dut0.sys_array.systolic_weights[j][i],
        dut0.sys_array.systolic_psums[j][i],
    );
    $display("| Output Weight/PSUM: %0d", dut0.sys_array.systolic_outputs[j][i]);
    $display("|----------------------------------|");
endfunction

function print_weight_r();
    $display("Systolic Array Weights (R)\n");
    for (j = 0; j < NUM_ROWS; j += 1) begin
        $write("[");
        for (i = 0; i < NUM_COLS; i += 1) begin
            $write("%2d", dut0.sys_array.systolic_weights[j][i]);
        end
        $write("]\n");
    end
endfunction

// Load Weight Mem
function load_mem(string mem, string file);
    $display("Loading %0s Memory", mem);;
    case (mem)
        "I":    $readmemh(file, dut0.input_mem.mem_array);
        "W":    $readmemh(file, dut0.weight_mem.mem_array);
        default:$display("Invalid memory type: %0s", mem);
    endcase
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
    @(negedge clk);
    i_start = 1'b1;
    count_en = 1'b1;

    // de-assert start
    @(negedge clk);
    i_start = 1'b0;
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
    load_mem("W", "bin/weight_rom.hex");

    // start preload
    start_matmul();

    repeat(NUM_ROWS + 2) @(negedge clk);

    print_weight_r();
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
task automatic smoke_random_mult;
    // reset
    reset_signals();

    // generate random activations and weights
    load_mem("W", "bin/weight_rom.hex");
    load_mem("I", "bin/input_rom.hex");

    // start matmul
    start_matmul();
    
    @(posedge o_done);

    // verify output (for now we just dump it into output_mem.hex)
    $writememh("bin/output_mem.hex", dut0.output_mem.mem_array);
    
endtask

endmodule
`default_nettype wire