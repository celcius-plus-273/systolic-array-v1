///////////////////////
/// PACKAGE: SA_PKG ///
///////////////////////
package sa_pkg;
    typedef enum logic [1:0] {  
        IDLE    = 2'b00,
        PRELOAD = 2'b01,
        STREAM  = 2'b10,
        FLUSH   = 2'b11,
        STATEX  = 2'bxx
    } sa_state_e;

    typedef struct packed {
        // weight offset
        // input offset
        // output offset
        // streaming dimension (M)
    } data_config_s;
endpackage

////////////////////////
/// INTERFACE: PE_IF ///
////////////////////////
// interface pe_if
// #(
//     parameter ADD_DATAWIDTH,
//     parameter MUL_DATAWIDTH
// )();
//
// endinterface

