import sa_pkg::*;

module sa_control
#(
    // memory parameters
    parameter INPUT_MEM_WIDTH,
    parameter WEIGHT_MEM_WIDTH,
    parameter OUTPUT_MEM_WIDTH,

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
    output logic                            r_input_en,
    output logic [INPUT_MEM_WIDTH-1 : 0]    r_input_addr,

    // i_weight memory interface
    output logic                            r_weight_en,
    output logic [WEIGHT_MEM_WIDTH-1 : 0]   r_weight_addr,

    // o_act memory interface
    output logic                            w_output_en,
    output logic [OUTPUT_MEM_WIDTH-1 : 0]   w_output_addr,

    // o_psum memory interface (won't use for now)

    // data config (check sa_pkg) (won't use for now)

    //-- control signals --//
    input logic i_en,           // clock gating?
    input logic i_start,        // mult start
    output logic o_done,        // mult done

    //-- systolic signals --//
    output logic o_mode,
    output logic o_load_psum
);
    //-- localparams --//
    localparam MAX_COUNT   = (NUM_COLS + NUM_ROWS - 1) + NUM_COLS
    localparam COUNT_WIDTH = $clog2(MAX_COUNT);

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
        next_state = 'x;
        next_count = 'x;

        case (curr_state)
            IDLE: begin
                next_state = i_start ? PRELOAD : IDLE;
                next_count = '0;
            end
            PRELOAD: begin
                // we are done preloading after NUM_ROWS cycles
                next_state = (count_r == (NUM_ROWS - 1)) ? STREAM : PRELOAD;
                // increment count (reset when we are done :))
                next_count = (count_r == (NUM_ROWS - 1)) ? '0 : count_r + 1'b1;
            end
            STREAM: begin
                // keep streaming for (cols + rows - 1 + cols) cycles
                next_state = (count_r == (MAX_COUNT - 1)) ? IDLE : STREAM;
                // increment count
                next_count = (count_r == (MAX_COUNT - 1)) ? '0 : count_r + 1'b1;
            end
            default: begin
                next_state = 'x;
                next_count = 'x;
            end
        endcase
    end

    //-- output ff --//
    always_ff @( posedge clk or negedge rst_n ) begin : output_ff
        if (!rst_n) begin
            // reset memory addr pointers
            r_input_en      <= 1'b0;
            r_input_addr    <= '0;
            r_weight_en     <= 1'b0;
            r_weight_addr   <= '0;
            w_output_en     <= 1'b0;
            w_output_addr   <= '0;

            // reset o_done
            o_done <= 1'b0;

            // systolic outputs
            o_mode      <= 1'b0;
            o_load_psum <= 1'b0;
        end
        else begin
            // default outputs
            r_input_en      <= 1'b0;
            r_input_addr    <= '0;
            r_weight_en     <= 1'b0;
            r_weight_addr   <= '0;
            w_output_en     <= 1'b0;
            w_output_addr   <= '0;
            // o_done <= 1'b0; // we actually want o_done to preserve it's prev value
            o_mode      <= 1'b0;
            o_load_psum <= 1'b0;

            case (next_state)
                IDLE: begin
                    // set output to done?
                    o_done = 1'b1;
                end
                PRELOAD: begin
                    // need to en weight read
                    r_weight_en <= 1'b1;
                    r_weight_addr <= r_weight_en ? r_weight_addr + 1'b1 : r_weight_addr;

                    o_mode = 1'b0; // set systolic to preload
                    o_done <= 1'b0; // actually reset o_done :)
                end
                STREAM: begin
                    // we enable read act inputs for COLS + ROWS - 1 cycles
                    r_input_en <= (count_r <= (NUM_COLS + NUM_ROWS - 2)) ? 1'b1 : 1'b0; 
                    r_input_addr <= r_input_en ? r_input_addr + 1'b1 : r_input_addr;

                    // next we enable write output acts for remaining cycles
                    // note that there is one cycle of overlap!
                    w_output_en <= (count_r >= (NUM_COLS + NUM_ROWS - 2)) ? 1'b1 : 1'b0; 
                    w_output_addr <= w_output_en ? w_output_addr + 1'b1 : w_output_addr;

                    o_mode = 1'b1;      // set systolic to compute mode
                    o_load_psum = 1'b1; // we need to clear the i_weight port or just swtich it to psum (will be tied to 0)
                end
                default: 
                    r_input_en      <= 'x;
                    r_input_addr    <= 'x;
                    r_weight_en     <= 'x;
                    r_weight_addr   <= 'x;
                    w_output_en     <= 'x;
                    w_output_addr   <= 'x;
                    o_done          <= 'x;
            endcase
        end
    end

endmodule