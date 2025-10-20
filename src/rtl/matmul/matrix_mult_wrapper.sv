module matrix_mult_wrapper_<GROUP_NUMBER> #(
    parameter WIDTH         = 8, 
    parameter ROW           = 4, 
    parameter COL           = 4, 
    parameter W_SIZE        = 256, 
    parameter I_SIZE        = 256, 
    parameter O_SIZE        = 256,
    parameter MEM_R_WIDTH   = WIDTH * ROW ,
    parameter MEM_C_WIDTH   = WIDTH * COL ,
    parameter DRIVER_WIDTH  = WIDTH * ( ROW + COL )
) (
  input  logic                        clk_i,            // clock signal
  input  logic                        rstn_async_i,     // active low reset signal
  input  logic                        en_i,             // global clock enable
  input  logic                        start_i,          // active high start calculation, must reset back to 0 first to start a new calculation
  input  test_config_struct           test_config_i,    // test controls
  input  data_config_struct           data_config_i,    // data controls
  // output buffer memory
  output  logic                       ob_mem_cenb_o,   // memory enable, active low
  output  logic                       ob_mem_wenb_o,   // write enable, active low
  output  logic [$clog2(O_SIZE)-1:0]  ob_mem_addr_o,   // address
  input   logic [MEM_C_WIDTH-1:0]     ob_mem_data_i,   // input data
  output  logic [MEM_C_WIDTH-1:0]     ob_mem_data_o,   // output data
  // input buffer memory
  output  logic                       ib_mem_cenb_o,   // memory enable, active low
  output  logic                       ib_mem_wenb_o,   // write enable, active low
  output  logic [$clog2(I_SIZE)-1:0]  ib_mem_addr_o,   // address
  input   logic [MEM_R_WIDTH-1:0]     ib_mem_data_i,   // input data
  // weights buffer memory
  output  logic                       wb_mem_cenb_o,   // memory enable, active low
  output  logic                       wb_mem_wenb_o,   // write enable, active low
  output  logic [$clog2(W_SIZE)-1:0]  wb_mem_addr_o,   // address
  input   logic [MEM_C_WIDTH-1:0]      wb_mem_data_i,   // input data
  // partial sum buffer memory
  output  logic                       ps_mem_cenb_o,   // memory enable, active low
  output  logic                       ps_mem_wenb_o,   // write enable, active low
  output  logic [$clog2(W_SIZE)-1:0]  ps_mem_addr_o,   // address
  input   logic [MEM_C_WIDTH-1:0]     ps_mem_data_i,   // input data
  output  logic [MEM_C_WIDTH-1:0]     ps_mem_data_o,   // output data
  // external mode
  input  logic                        ext_en_i,        // external mode enable, acitve high
  input  external_inputs_struct       ext_inputs_i,    // external inputs
  output logic [DRIVER_WIDTH-1:0]     ext_result_o,    // external outputs
  output logic                        ext_valid_o,     // external valid output
  // sample clock
  output logic                        sample_clk_o,    // sample clock used for dll
  // done
  output logic                        done_o           // active high finish signal, goes to 1 after reset
);

  logic                       rstn_i;
  logic                       dut_bypass_w;
  logic                       g_clk;

  logic                       driver_bypass_w;
  logic                       driver_mode_w;
  logic [DRIVER_WIDTH-1:0]    driver_seed_w;
  logic                       driver_valid_o_w;
  logic [DRIVER_WIDTH-1:0]    driver_data_w;
  logic                       driver_done_w;

  logic                       sa_bypass_w;
  logic                       sa_mode_w;
  logic                       sa_dut_valid_w;
  logic [DRIVER_WIDTH-1:0]    sa_dut_data_w;
  logic                       sa_valid_w;
  logic [DRIVER_WIDTH-1:0]    sa_data_w;
  logic [DRIVER_WIDTH-1:0]    sa_seed_w;
  logic                       sa_stop_w;


  logic [ROW-1:0][WIDTH-1:0]  ext_input_w;
  logic                       ext_valid_i_w;
  logic [COL-1:0][WIDTH-1:0]  ext_psum_w;
  logic [COL-1:0][WIDTH-1:0]  ext_result_w;
  logic                       ext_valid_o_w;

  external_inputs_struct      ext_inputs_w;

  logic [COL-1:0][WIDTH-1:0]  ob_mem_data_i_w;
  logic [COL-1:0][WIDTH-1:0]  ob_mem_data_o_w;
  logic [COL-1:0][WIDTH-1:0]  ib_mem_data_i_w;
  logic [COL-1:0][WIDTH-1:0]  wb_mem_data_i_w;
  logic [COL-1:0][WIDTH-1:0]  ps_mem_data_i_w;
  logic [COL-1:0][WIDTH-1:0]  ps_mem_data_o_w;

  // explicitly convert 2D arrays to 1D arrays
  assign ob_mem_data_i_w  = ob_mem_data_i ;
  assign ob_mem_data_o    = ob_mem_data_o_w ;
  assign ib_mem_data_i_w  = ib_mem_data_i ;
  assign wb_mem_data_i_w  = wb_mem_data_i ;
  assign ps_mem_data_i_w  = ps_mem_data_i ;
  assign ps_mem_data_o    = ps_mem_data_o_w ;

  // sample clock and global clock
  assign sample_clk_o     = clk_i;
  assign g_clk            = clk_i & en_i; 

  // test control signals
  assign driver_bypass_w  = test_config_i.bypass[0];
  assign dut_bypass_w     = test_config_i.bypass[1];
  assign sa_bypass_w      = test_config_i.bypass[2];

  assign driver_mode_w    = test_config_i.mode[0];
  assign sa_mode_w        = test_config_i.mode[1];

  // connect seeds
  assign driver_seed_w    = { ext_inputs_i.ext_input, ext_inputs_i.ext_psum };
  assign sa_seed_w        = ext_inputs_i.ext_psum;

  // bypass external inputs that never go through the driver
  assign ext_inputs_w.ext_weight_en   = ext_inputs_i.ext_weight_en;
  assign ext_inputs_w.ext_input       = ext_input_w;
  assign ext_inputs_w.ext_valid       = ext_valid_i_w;
  assign ext_inputs_w.ext_weight      = ext_inputs_i.ext_weight ;
  assign ext_inputs_w.ext_psum        = ext_psum_w;

  //-------------------------------------------------------------------------//
  //    Reset synchronizer                                                   //
  //-------------------------------------------------------------------------//
	async_nreset_synchronizer async_nreset_synchronizer_0 (
		 .clk_i			    (g_clk			  )
		,.async_nreset_i(rstn_async_i	)
		,.rstn_o		    (rstn_i			  )
	);

  //-------------------------------------------------------------------------//
  //    Driver                                                               //
  //-------------------------------------------------------------------------//
  pseudo_rand_num_gen #(.DATA_WIDTH (DRIVER_WIDTH)) 
    driver_0 (
      .clk_i        (g_clk                            ),
      .rstn_i       (rstn_i                           ),
      .bypass_i     (driver_mode_w                    ),
      .valid_i      (test_config_i.driver_valid       ),
      .seed_i       (driver_seed_w                    ),
      .stop_code_i  (test_config_i.driver_stop_code   ),
      .valid_o      (driver_valid_o_w                 ),
      .data_o       (driver_data_w                    ),
      .done_o       (driver_done_w                    )
    );

  // driver bypass
  assign { ext_input_w, ext_psum_w } = ( driver_bypass_w)  ? { ext_inputs_i.ext_input, ext_inputs_i.ext_psum } : driver_data_w;
  assign ext_valid_i_w               = ( driver_bypass_w)  ? ext_inputs_i.ext_valid : driver_valid_o_w; 

  //-------------------------------------------------------------------------//
  //    Matrix mult                                                          //
  //-------------------------------------------------------------------------//
  // matrix_mult_<GROUP_NUMBER> #( .WIDTH(WIDTH) , .ROW(ROW) , .COL(COL) , .W_SIZE(W_SIZE) , .I_SIZE(I_SIZE) , .O_SIZE(O_SIZE) )
  //   matrix_mult_<GROUP_NUMBER> (
  //     .clk_i                (g_clk                ),
  //     .rstn_i               (rstn_i               ),
  //     .start_i              (start_i              ),
  //     .data_config_i        (data_config_i        ),
  //     .ob_mem_cenb_o        (ob_mem_cenb_o        ),
  //     .ob_mem_wenb_o        (ob_mem_wenb_o        ),
  //     .ob_mem_addr_o        (ob_mem_addr_o        ),
  //     .ob_mem_data_o        (ob_mem_data_o_w      ),
  //     .ob_mem_data_i        (ob_mem_data_i_w      ),
  //     .ib_mem_cenb_o        (ib_mem_cenb_o        ),
  //     .ib_mem_wenb_o        (ib_mem_wenb_o        ),
  //     .ib_mem_addr_o        (ib_mem_addr_o        ),
  //     .ib_mem_data_i        (ib_mem_data_i_w      ),
  //     .wb_mem_cenb_o        (wb_mem_cenb_o        ),
  //     .wb_mem_wenb_o        (wb_mem_wenb_o        ),
  //     .wb_mem_addr_o        (wb_mem_addr_o        ),
  //     .wb_mem_data_i        (wb_mem_data_i_w      ),
  //     .ps_mem_cenb_o        (ps_mem_cenb_o        ),
  //     .ps_mem_wenb_o        (ps_mem_wenb_o        ),
  //     .ps_mem_addr_o        (ps_mem_addr_o        ),
  //     .ps_mem_data_o        (ps_mem_data_o_w      ),
  //     .ps_mem_data_i        (ps_mem_data_i_w      ),
  //     .ext_en_i             (ext_en_i             ),
  //     .ext_inputs_i         (ext_inputs_w         ),
  //     .ext_result_o         (ext_result_w         ),
  //     .ext_valid_o          (ext_valid_o_w        ),
  //     .done_o               (done_o               )
  //   );

  // dut bypass
  assign sa_dut_data_w  = ( dut_bypass_w ) ? { ext_input_w, ext_psum_w } : { {(WIDTH*ROW){1'b0}}, ext_result_w } ;
  assign sa_dut_valid_w = ( dut_bypass_w ) ? ext_valid_i_w : ext_valid_o_w ;
  assign sa_stop_w      = driver_done_w;

  //-------------------------------------------------------------------------//
  //    Monitor                                                              //
  //-------------------------------------------------------------------------//
  signature_analyzer #(.DATA_WIDTH (DRIVER_WIDTH) ) 
    monitor_0 (
      .clk_i        (g_clk          ),
      .rstn_i       (rstn_i         ),
      .bypass_i     (sa_mode_w      ),     
      .stop_i       (sa_stop_w      ),     
      .seed_i       (sa_seed_w      ),
      .dut_valid_i  (sa_dut_valid_w ),     
      .dut_data_i   (sa_dut_data_w  ),
      .valid_o      (sa_valid_w     ),
      .data_o       (sa_data_w      )
    );

  // signature analyzer bypass
  assign ext_result_o = (sa_bypass_w) ? sa_dut_data_w : sa_data_w ;
  assign ext_valid_o  = (sa_bypass_w) ? sa_dut_valid_w : sa_valid_w ;

endmodule