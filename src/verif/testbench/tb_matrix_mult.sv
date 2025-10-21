module tb_matrix_mult;

   parameter WIDTH         = 8;
   parameter ROW           = 4;
   parameter COL           = 4;
   parameter W_SIZE        = 256;
   parameter I_SIZE        = 256;
   parameter O_SIZE        = 256;
   parameter DRIVER_WIDTH  = WIDTH * ( ROW + COL );

   parameter CLOCK_PERIOD        = 10;
   parameter real DUTY_CYCLE     = 0.5;
   parameter real OFFSET         = 2.5;
   parameter CYCLE_LIMIT         = 20_000;
   
   logic                         clk_i;
   logic                         rstn_async_i;
   logic                         en_i;
   logic                         start_i;

   // test config
   logic [2:0]                   bypass_i;
   logic [1:0]                   mode_i;
   logic                         driver_valid_i;
   logic [DRIVER_WIDTH-1:0]      driver_stop_code_i;
   test_config_struct            test_config_i;

   // data config
   logic [$clog2(ROW)-1:0]       w_rows_i;
   logic [$clog2(COL)-1:0]       w_cols_i;
   logic [$clog2(I_SIZE)-1:0]    i_rows_i;
   logic [$clog2(W_SIZE)-1:0]    w_offset;
   logic [$clog2(I_SIZE)-1:0]    i_offset;
   logic [$clog2(O_SIZE)-1:0]    psum_offset_r;
   logic [$clog2(O_SIZE)-1:0]    o_offset_w;
   logic                         accum_enb_i;
   data_config_struct            data_config_i;

   // output buffer memory
   logic                         ob_mem_cenb_o;
   logic                         ob_mem_wenb_o;
   logic [$clog2(O_SIZE)-1:0]    ob_mem_addr_o;
   logic [COL-1:0][WIDTH-1:0]    ob_mem_data_i;
   logic [COL-1:0][WIDTH-1:0]    ob_mem_data_o;
   // input buffer memory
   logic                         ib_mem_cenb_o;
   logic                         ib_mem_wenb_o;
   logic [$clog2(I_SIZE)-1:0]    ib_mem_addr_o;
   logic [ROW-1:0][WIDTH-1:0]    ib_mem_data_i;
   // weights buffer memory
   logic                         wb_mem_cenb_o;
   logic                         wb_mem_wenb_o;
   logic [$clog2(W_SIZE)-1:0]    wb_mem_addr_o;
   logic [COL-1:0][WIDTH-1:0]    wb_mem_data_i;
   // partial sum buffer memory
   logic                         ps_mem_cenb_o;
   logic                         ps_mem_wenb_o;
   logic [$clog2(W_SIZE)-1:0]    ps_mem_addr_o;
   logic [COL-1:0][WIDTH-1:0]    ps_mem_data_i;
   logic [COL-1:0][WIDTH-1:0]    ps_mem_data_o;

   // external config
   logic                         ext_en_i;
   logic [ROW-1:0][WIDTH-1:0]    ext_input_i;
   logic [COL-1:0][WIDTH-1:0]    ext_weight_i;
   logic [COL-1:0][WIDTH-1:0]    ext_psum_i;
   logic                         ext_weight_en_i;
   external_inputs_struct        ext_inputs_i;
   logic [DRIVER_WIDTH-1:0]      ext_result_o;
   logic                         ext_valid_o;

   logic                         sample_clk_o;
   logic                         done_o;

   // outputs memory
   logic                         ob_mem_cenb_w;
   logic                         ob_mem_wenb_w;
   logic [$clog2(O_SIZE)-1:0]    ob_mem_addr_w;
   logic [COL*WIDTH-1:0]         ob_mem_d_i_w;
   logic [COL*WIDTH-1:0]         ob_mem_q_o_w;

   assign test_config_i.bypass                 = bypass_i;
   assign test_config_i.mode                   = mode_i;
   assign test_config_i.driver_valid           = driver_valid_i;
   assign test_config_i.driver_stop_code       = driver_stop_code_i;

   assign data_config_i.w_rows                 = w_rows_i;
   assign data_config_i.w_cols                 = w_cols_i;
   assign data_config_i.i_rows                 = i_rows_i;
   assign data_config_i.w_offset               = w_offset;
   assign data_config_i.i_offset               = i_offset;
   assign data_config_i.psum_offset            = psum_offset_r;
   assign data_config_i.o_offset_w             = o_offset_w;
   assign data_config_i.accum_en               = accum_enb_i;

   assign ext_inputs_i.ext_input               = ext_input_i;
   assign ext_inputs_i.ext_weight              = ext_weight_i;
   assign ext_inputs_i.ext_psum                = ext_psum_i;
   assign ext_inputs_i.ext_weight_en           = ext_weight_en_i;
   
   assign ob_mem_cenb_w                        = ob_mem_cenb_o;
   assign ob_mem_wenb_w                        = ob_mem_wenb_o;
   assign ob_mem_addr_w                        = ob_mem_addr_o;
   assign ob_mem_d_i_w                         = ob_mem_data_o;
   assign ob_mem_data_i                        = ob_mem_q_o_w;

   logic [1000:0] testname;
   integer        returnval;
   string         filename;
   integer        f;
   
   initial begin
      #OFFSET;
      forever begin
         clk_i = 1'b0;
         #(CLOCK_PERIOD-(CLOCK_PERIOD*DUTY_CYCLE)) clk_i = 1'b1;
         #(CLOCK_PERIOD*DUTY_CYCLE);
      end
   end

   // Input Memory //
   mem_emulator #(
      .WIDTH(ROW*WIDTH),
      .SIZE(I_SIZE)
   ) input_mem (
      .clk_i(clk_i),
      // cenb & wenb
      .cenb_i(ib_mem_cenb_o),
      .wenb_i(ib_mem_wenb_o),
      // addr & data
      .addr_i(ib_mem_addr_o),     // addr port
      .d_i(),                     // not connected
      .q_o(ib_mem_data_i)         // data port
   );

   // weight buffer/memory
   mem_emulator #(
      .WIDTH(ROW*WIDTH),
      .SIZE(I_SIZE)
   ) weight_mem (
      .clk_i   (clk_i),
      .cenb_i  (wb_mem_cenb_o),
      .wenb_i  (wb_mem_wenb_o),
      .addr_i  (wb_mem_addr_o),  // addr port
      .d_i     (),               // not connected
      .q_o     (wb_mem_data_i)   // data port
   );

   // output buffer/memory
   mem_emulator #(.WIDTH(COL*WIDTH), .SIZE(O_SIZE))
      output_mem (
         .clk_i   (clk_i            ),
         .cenb_i  (ob_mem_cenb_w    ),
         .wenb_i  (ob_mem_wenb_w    ),
         .addr_i  (ob_mem_addr_w    ),
         .d_i     (ob_mem_d_i_w     ),
         .q_o     (ob_mem_q_o_w     )
   );

   //-------------------------//
   //---- MAT MUL WRAPPER ----//
   //-------------------------//
   matrix_mult_wrapper #(
      .WIDTH   (WIDTH   ),
      .ROW     (ROW     ),
      .COL     (COL     ),
      .W_SIZE  (W_SIZE  ),
      .I_SIZE  (I_SIZE  ),
      .O_SIZE  (O_SIZE  )
   ) dut0 (.*);

   // Watchdog Timer
   bit [$clog2(CYCLE_LIMIT):0] watchdog;

   always @(posedge clk_i) begin
      if (driver_valid_i) watchdog += 1;

      if (watchdog == CYCLE_LIMIT) begin
         $display("Watchdog triggered!");
         $display("LFSR Out: %0h", dut0.driver_data_w);
         $finish;
      end
   end

   // Test variables
   int cycle = 0;
   bit count_en;
   int returnval;
   string testname;
   integer num_tests;
   string dumpfile = "matmul";
   string file_path; // used in iterative tests

   initial begin
      returnval = $value$plusargs("testname=%s", testname);
      returnval = $value$plusargs("numtests=%d", num_tests);

      $display("---- Running Test: %0s ----", testname);
      $display("Number of Tests: %0d", num_tests);

      `ifdef VCS
         // FSDB Dump (Waveform)
         $fsdbDumpfile({dumpfile,".fsdb"});
         $fsdbDumpvars(0, dut0);
         $fsdbDumpon;
      `else
         $dumpfile({dumpfile,".fsdb"});
         $dumpvars(0, dut0);
      `endif

      `ifdef SDF 
         $sdf_annotate("./matrix_mult.wc.sdf", dut0, "./sdf.max.cfg");
      `endif

   end

   initial begin
      // reset signals
      reset_signals();

      case(testname)
      	 "external":   run_rand_mult(num_tests);
      	 "memory":     run_rand_mult(num_tests);
      	 "bist":       run_bist();
      	 default:      run_rand_mult(num_tests);
      endcase

      // exit sim
      $finish;
   end

   always @(posedge clk_i) begin
      if (count_en) cycle += 1;
   end

   // --------------------------------------- //
   //--------- General Functions ------------ //
   // --------------------------------------- //
   int i, j, n; // for loops

   // Load Weight Mem
   function load_mem(string mem, string file);
      // $display("Loading %0s Memory", mem);
      case (mem)
         "I":        $readmemh(file, input_mem.data);
         "W":        $readmemh(file, weight_mem.data);
         default:    $display("Invalid memory type: %0s", mem);
      endcase
   endfunction

   // ----------------------------------- //
   //--------- General Tasks ------------ //
   // ----------------------------------- //
   // reset common signals
   task automatic reset_common_control();
      // data config
      w_rows_i       = '0; // not used
      w_cols_i       = '0; // not used
      i_rows_i       = '0; // streaming dimension
      w_offset       = '0; // weight memory offset
      i_offset       = '0; // input memory offset
      psum_offset_r  = '0; // psum memory offset (not used)
      o_offset_w     = '0; // output memory offset
      accum_enb_i    = 1'b0;  // not used

      // external config
      ext_en_i       = 1'b0;  // enable external mode
      ext_input_i    = '0;    // external input act
      ext_weight_i   = '0;    // external weight
      ext_psum_i     = '0;    // external psum
      ext_weight_en_i = 1'b0; // external weight control signal
   endtask

   // reset condition for memory mode signals
   task automatic init_memory_control();
      // test config
      bypass_i             = 3'b101;   // bypass driver and monitor
      mode_i               = 2'b00;    // don't care for for this mode
      driver_valid_i       = 1'b0;     // disbable driver
      driver_stop_code_i   = '0;       // don't care

      reset_common_control();
   endtask

   // reset condition for memory mode signals
   task automatic init_external_control();
      // test config
      bypass_i             = 3'b101;   // connect external inputs directly to DUT
      mode_i               = 2'b00;    // don't care
      driver_valid_i       = 1'b0;     // disable driver
      driver_stop_code_i   = '0;       // don't care

      reset_common_control();

      // enable external mode
      ext_en_i = 1'b1;
   endtask

   // reset condition for memory mode signals
   task automatic init_bist_control();
      // test config
      bypass_i             = 3'b000;   // no bypass
      mode_i               = 2'b00;    // LSFR & SA mode
      driver_valid_i       = 1'b0;     // enable driver when ready (need to preload weights first)
      // load LFSR stop code (note this is 64 bits)
      driver_stop_code_i   = 64'h5ada_f497_9ca7_3444; // 10_000 LFSR cycles + dead_dead_abcd_abcd seed

      reset_common_control();

      // enable external mode
      ext_en_i = 1'b1;

      // set driver and sa seed
      ext_input_i = 32'hdead_dead;
      ext_psum_i = 32'habcd_abcd;
   endtask

   // reset signals / init signals
   task automatic reset_signals();
      // toggle reset
      rstn_async_i = 1'b0;

      // reset control signals
      start_i = 1'b0;
      en_i = 1'b1;   // enable gclk

      // set signals based on test case (bypass driver and monitor for now)
      case(testname)
      	 "external": begin
               init_external_control();
          end
      	 "memory": begin
               init_memory_control();
          end
      	 "bist": begin
               init_bist_control();
          end
      endcase

      // wait two cycles
      repeat(2) @(posedge clk_i);

      // de-assert reset
      rstn_async_i = 1'b1;

      // wait for synchronized reset
      repeat(10) @(posedge clk_i);
   endtask

   task automatic start_matmul();
      // assert start
      @(negedge clk_i);
      start_i = 1'b1;
      count_en = 1'b1;

      // de-assert start
      @(negedge clk_i);
      start_i = 1'b0;
   endtask

   task automatic run_rand_mult (int num_tests);
      for (int i = 0; i < num_tests; i += 1) begin

         // binary path
         file_path = $sformatf("bin/random/test_%0d/", i);

         $display("Running test: %0d", i);
         $display("Binary path: %0s", file_path);

         // reset module
         reset_signals();

         // generate random activations and weights
         load_mem("W", {file_path, "weight_rom.hex"});
         load_mem("I", {file_path, "input_rom.hex"});

         // start matmul
         start_matmul();
    
         // results are ready
         @(posedge done_o);

         // dump dut output
         $writememh({file_path, "output_mem.hex"}, output_mem.data);
      end
   endtask

   task automatic load_weights_external();
      // load weights
      ext_weight_en_i   = 1'b1;  // load mode

      // weights are loaded reversed
      ext_weight_i      = 32'habcd;
      @(posedge clk_i); // wait one cycle

      ext_weight_i      = 32'hdcba;
      @(posedge clk_i); // wait one cycle

      ext_weight_i      = 32'hdead;
      @(posedge clk_i); // wait one cycle

      ext_weight_i      = 32'hfeed;
      @(posedge clk_i); // wait one cycle

      ext_weight_en_i   = 1'b0;  // disable load mode
   endtask

   task automatic run_bist();
      reset_signals();

      // load weights
      load_weights_external();

      // enable LFSR
      driver_valid_i = 1'b1;

      // wait until signature analyzer is done
      // this should be one cycle after the LFSR finds the stop code
      @(posedge ext_valid_o) begin
         // $display("Signature is ready!");
         // $display("%0h", ext_result_o);
         if (64'h7ccc_b994_1669_06cc == ext_result_o) begin
            $display("----------------------");
            $display("------- PASSED -------");
            $display("----------------------");
         end else begin
            $display("----------------------");
            $display("------- FAILED -------");
            $display("----------------------");
         end

         $finish;
      end
   endtask

// `include "./tasks.sv"
endmodule 
