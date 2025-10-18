
module sa_control
#(
    // memory parameters
    parameter INPUT_WIDTH,      // input mem width
    parameter INPUT_HEIGHT,     // input mem height
    parameter WEIGHT_WIDTH,     // weight mem width
    parameter WEIGHT_HEIGHT,    // weight mem height
    parameter OUTPUT_WIDTH,     // output mem width
    parameter OUTPUT_HEIGHT,    // output mem height

    // array params
    parameter NUM_ROWS,
    parameter NUM_COLS
) (
    // clk, rst
    input logic clk,
    input logic rst_n,

    //-- Memory Interfaces --//
    // for now we will use fake memories that rely on a start signal :)
    // i_act memory interface
    output logic                                r_input_cenb,
    output logic                                r_input_wenb,
    output logic [$clog2(INPUT_HEIGHT)-1 : 0]   r_input_addr,

    // i_weight memory interface
    output logic                                r_weight_cenb,
    output logic                                r_weight_wenb,
    output logic [$clog2(WEIGHT_HEIGHT)-1 : 0]  r_weight_addr,

    // o_act memory interface
    output logic                                w_output_cenb,
    output logic                                w_output_wenb,
    output logic [$clog2(OUTPUT_HEIGHT)-1 : 0]  w_output_addr,

    // o_psum memory interface (won't use for now)

    // data config (check sa_pkg) (won't use for now)

    //-- control signals --//
    // input logic i_en,           // clock gating?
    input logic i_start,        // mult start
    output logic o_done,        // mult done

    //-- systolic signals --//
    output logic o_mode,
    output logic o_load_psum
);
    //-- localparams  & imports --//
    import sa_pkg::*;
    // two extra cycles:
    // 1 for fetching stream memory
    // 1 for writing the last output activation
    localparam MAX_COUNT   = (1 + NUM_COLS + NUM_ROWS - 1) + (NUM_COLS + 1);
    localparam COUNT_WIDTH = $clog2(MAX_COUNT);

    localparam PRELOAD_CYCLES       = 1 + NUM_ROWS;
    localparam STREAM_IACT_CYCLES   = 1 + NUM_COLS + NUM_ROWS - 1;
    localparam OUTPUT_START_WRITE   = 1 + NUM_COLS;

    //-- state variable --//
    sa_state_e curr_state, next_state;

    //-- internal counter --//
    logic [COUNT_WIDTH-1 : 0] count_r, next_count;

    //-- state update ff --//
    always_ff @( posedge clk or negedge rst_n ) begin : state_update_ff
        if (!rst_n) begin
            // reset values
            curr_state  <= IDLE;     // IDLE is reset
            count_r     <= '0;       // reset count
        end 
        else begin
            // normal operation
            curr_state  <= next_state;
            count_r     <= next_count;
        end
    end

    //-- next state comb --//
    always_comb begin : next_state_comb
        // default assignments
        next_state = STATEX;
        next_count = 'x;

        case (curr_state)
            IDLE: begin
                next_state = i_start ? PRELOAD : IDLE;
                next_count = '0;
            end
            PRELOAD: begin
                // preload cycles
                next_state = (count_r == (PRELOAD_CYCLES - 1)) ? STREAM : PRELOAD;
                // increment count (reset when we are done :))
                next_count = (count_r == (PRELOAD_CYCLES - 1)) ? '0 : count_r + 1'b1;
            end
            STREAM: begin
                // keep streaming for (cols + rows - 1 + cols) cycles
                next_state = (count_r == (MAX_COUNT - 1)) ? IDLE : STREAM;
                // increment count
                next_count = (count_r == (MAX_COUNT - 1)) ? '0 : count_r + 1'b1;
            end
            default: begin
                next_state = STATEX;
                next_count = 'x;
            end
        endcase
    end

    //-- output ff --//
    always_ff @( posedge clk or negedge rst_n ) begin : output_ff
        if (!rst_n) begin
            // reset memory addr pointers
            r_input_cenb    <= 1'b1;
            r_input_wenb    <= 1'b1;
            r_input_addr    <= '0;
            r_weight_cenb   <= 1'b1;
            r_weight_wenb   <= 1'b1;
            r_weight_addr   <= '0;
            w_output_cenb   <= 1'b1;
            w_output_wenb   <= 1'b1;
            w_output_addr   <= '0;

            // reset o_done
            o_done <= 1'b0;

            // systolic outputs
            o_mode      <= 1'b0;
            o_load_psum <= 1'b0;
        end
        else begin
            // default outputs
            r_input_cenb    <= 1'b1;
            r_input_wenb    <= 1'b1;
            r_input_addr    <= '0;
            r_weight_cenb   <= 1'b1;
            r_weight_wenb   <= 1'b1;
            r_weight_addr   <= '0;
            w_output_cenb   <= 1'b1;
            w_output_wenb   <= 1'b1;
            w_output_addr   <= '0;

            // o_done <= 1'b0; // we actually want o_done to preserve it's prev value
            o_mode      <= 1'b0;
            o_load_psum <= 1'b0;

            case (curr_state)
                IDLE: begin
                    // for the future might want to add ready signal :)
                    o_done <= 1'b1;
                end
                PRELOAD: begin
                    r_weight_cenb <= 1'b0;                                                  // enable weight mem
                    r_weight_wenb <= 1'b1;                                                  // read mode
                    r_weight_addr <= r_weight_cenb ? r_weight_addr : r_weight_addr + 1'b1;  // addr

                    o_mode <= 1'b0; // set systolic to preload
                    o_done <= 1'b0; // actually reset o_done :)
                end
                STREAM: begin
                    // we enable read act inputs for COLS + ROWS - 1 cycles
                    r_input_cenb <= (count_r <= (STREAM_IACT_CYCLES - 1)) ? 1'b0 : 1'b1;     // enable act mem
                    r_input_wenb <= 1'b1;                                                   // read mode
                    r_input_addr <= r_input_cenb ? r_input_addr : r_input_addr + 1'b1;      // addr

                    // next we enable write output acts for remaining cycles
                    // note that there is one cycle of overlap!
                    w_output_cenb <= (count_r >= (OUTPUT_START_WRITE)) ? 1'b0 : 1'b1;       // enable output mem
                    w_output_wenb <= 1'b0;                                                  // write mode
                    w_output_addr <= w_output_cenb ? w_output_addr : w_output_addr + 1'b1;  // addr


                    o_mode      <= 1'b1; // set systolic to compute mode
                    o_load_psum <= 1'b1; // we need to clear the i_weight port or just swtich it to psum (will be tied to 0)
                end
                default: begin
                    // for debug purposes
                    r_input_cenb    <= 'x;
                    r_input_wenb    <= 'x;
                    r_input_addr    <= 'x;
                    r_weight_cenb   <= 'x;
                    r_weight_wenb   <= 'x;
                    r_weight_addr   <= 'x;
                    w_output_cenb   <= 'x;
                    w_output_wenb   <= 'x;
                    w_output_addr   <= 'x;
                    o_mode          <= 'x;
                    o_load_psum     <= 'x;
                    o_done          <= 'x;
                end
            endcase
        end
    end

endmodule