`default_nettype none
`timescale 1ns/1ps
/*
This module was generated with Manta v0.0.5 on 23 Dec 2023 at 18:34:35 by kiranv

If this breaks or if you've got spicy formal verification memes, contact fischerm [at] mit.edu

Provided under a GNU GPLv3 license. Go wild.

Here's an example instantiation of the Manta module you configured, feel free to copy-paste
this into your source!

manta manta_inst (
    .clk(clk),

    .rx(rx),
    .tx(tx),
    
    .data_valid_cc(data_valid_cc), 
    .data_valid_cb(data_valid_cb), 
    .cam_data_in(cam_data_in), 
    .cam_data_cb(cam_data_cb), 
    .vs_lo_long(vs_lo_long), 
    .hsync(hsync), 
    .pclk_cam_in(pclk_cam_in));

*/

module manta (
    input wire clk,

    input wire rx,
    output reg tx,
    
    input wire data_valid_cc,
    input wire data_valid_cb,
    input wire [7:0] cam_data_in,
    input wire [15:0] cam_data_cb,
    input wire vs_lo_long,
    input wire hsync,
    input wire pclk_cam_in);


    uart_rx #(.CLOCKS_PER_BAUD(64)) urx (
        .clk(clk),
        .rx(rx),
    
        .data_o(urx_brx_data),
        .valid_o(urx_brx_valid));
    
    reg [7:0] urx_brx_data;
    reg urx_brx_valid;
    
    bridge_rx brx (
        .clk(clk),
    
        .data_i(urx_brx_data),
        .valid_i(urx_brx_valid),
    
        .addr_o(brx_cam_logic_analyzer_addr),
        .data_o(brx_cam_logic_analyzer_data),
        .rw_o(brx_cam_logic_analyzer_rw),
        .valid_o(brx_cam_logic_analyzer_valid));
    reg [15:0] brx_cam_logic_analyzer_addr;
    reg [15:0] brx_cam_logic_analyzer_data;
    reg brx_cam_logic_analyzer_rw;
    reg brx_cam_logic_analyzer_valid;
    

    logic_analyzer cam_logic_analyzer (
        .clk(clk),
    
        .addr_i(brx_cam_logic_analyzer_addr),
        .data_i(brx_cam_logic_analyzer_data),
        .rw_i(brx_cam_logic_analyzer_rw),
        .valid_i(brx_cam_logic_analyzer_valid),
    
        .data_valid_cc(data_valid_cc),
        .data_valid_cb(data_valid_cb),
        .cam_data_in(cam_data_in),
        .cam_data_cb(cam_data_cb),
        .vs_lo_long(vs_lo_long),
        .hsync(hsync),
        .pclk_cam_in(pclk_cam_in),
    
        .addr_o(),
        .data_o(cam_logic_analyzer_btx_data),
        .rw_o(cam_logic_analyzer_btx_rw),
        .valid_o(cam_logic_analyzer_btx_valid));

    
    reg [15:0] cam_logic_analyzer_btx_data;
    reg cam_logic_analyzer_btx_rw;
    reg cam_logic_analyzer_btx_valid;
    bridge_tx btx (
        .clk(clk),
    
        .data_i(cam_logic_analyzer_btx_data),
        .rw_i(cam_logic_analyzer_btx_rw),
        .valid_i(cam_logic_analyzer_btx_valid),
    
        .data_o(btx_utx_data),
        .start_o(btx_utx_start),
        .done_i(utx_btx_done));
    
    reg [7:0] btx_utx_data;
    reg btx_utx_start;
    reg utx_btx_done;
    
    uart_tx #(.CLOCKS_PER_BAUD(64)) utx (
        .clk(clk),
    
        .data_i(btx_utx_data),
        .start_i(btx_utx_start),
        .done_o(utx_btx_done),
    
        .tx(tx));

endmodule

/* ---- Module Definitions ----  */

// Modified from Dan Gisselquist's rx_uart module,
// available at https://zipcpu.com/tutorial/ex-09-uartrx.zip

module uart_rx (
    input wire clk,

    input wire rx,

    output reg [7:0] data_o,
    output reg valid_o);

    parameter CLOCKS_PER_BAUD = 0;
    localparam IDLE = 0;
    localparam BIT_ZERO = 1;
    localparam STOP_BIT = 9;

    reg	[3:0] state = IDLE;
    reg	[15:0] baud_counter = 0;
    reg zero_baud_counter;
    assign zero_baud_counter = (baud_counter == 0);

    // 2FF Synchronizer
    reg ck_uart = 1;
    reg	q_uart = 1;
    always @(posedge clk)
        { ck_uart, q_uart } <= { q_uart, rx };

    always @(posedge clk)
        if (state == IDLE) begin
            state <= IDLE;
            baud_counter <= 0;
            if (!ck_uart) begin
                state <= BIT_ZERO;
                baud_counter <= CLOCKS_PER_BAUD+CLOCKS_PER_BAUD/2-1'b1;
            end
        end

        else if (zero_baud_counter) begin
            state <= state + 1;
            baud_counter <= CLOCKS_PER_BAUD-1'b1;
            if (state == STOP_BIT) begin
                state <= IDLE;
                baud_counter <= 0;
            end
        end

        else baud_counter <= baud_counter - 1'b1;

    always @(posedge clk)
        if ( (zero_baud_counter) && (state != STOP_BIT) )
            data_o <= {ck_uart, data_o[7:1]};

    initial	valid_o = 1'b0;
    always @(posedge clk)
        valid_o <= ( (zero_baud_counter) && (state == STOP_BIT) );

endmodule
module bridge_rx (
    input wire clk,

    input wire [7:0] data_i,
    input wire valid_i,

    output reg [15:0] addr_o,
    output reg [15:0] data_o,
    output reg rw_o,
    output reg valid_o);

    initial addr_o = 0;
    initial data_o = 0;
    initial rw_o = 0;
    initial valid_o = 0;

    function [3:0] from_ascii_hex;
        // convert an ascii char encoding a hex value to
        // the corresponding hex value
        input [7:0] c;

        if ((c >= 8'h30) && (c <= 8'h39)) from_ascii_hex = c - 8'h30;
        else if ((c >= 8'h41) && (c <= 8'h46)) from_ascii_hex = c - 8'h41 + 'd10;
        else from_ascii_hex = 0;
    endfunction

    function is_ascii_hex;
        // checks if a byte is an ascii char encoding a hex digit
        input [7:0] c;

        if ((c >= 8'h30) && (c <= 8'h39)) is_ascii_hex = 1; // 0-9
        else if ((c >= 8'h41) && (c <= 8'h46)) is_ascii_hex = 1; // A-F
        else is_ascii_hex = 0;
    endfunction

    reg [7:0] buffer [7:0]; // = 0; // todo: see if sby will tolerate packed arrays?

    localparam IDLE = 0;
    localparam READ = 1;
    localparam WRITE = 2;
    reg [1:0] state = 0;
    reg [3:0] byte_num = 0;

    always @(posedge clk) begin
        addr_o <= 0;
        data_o <= 0;
        rw_o <= 0;
        valid_o <= 0;

        if (state == IDLE) begin
            byte_num <= 0;
            if (valid_i) begin
                if (data_i == "R") state <= READ;
                if (data_i == "W") state <= WRITE;
           end
        end

        else begin
            if (valid_i) begin
                // buffer bytes regardless of if they're good
                byte_num <= byte_num + 1;
                buffer[byte_num] <= data_i;

                // current transaction specifies a read operation
                if(state == READ) begin

                    // go to idle if anything doesn't make sense
                    if(byte_num < 4) begin
                        if(!is_ascii_hex(data_i)) state <= IDLE;
                    end

                    else if(byte_num == 4) begin
                        state <= IDLE;

                        // put data on the bus if the last byte looks good
                        if((data_i == 8'h0D) || (data_i == 8'h0A)) begin
                            addr_o <=   (from_ascii_hex(buffer[0]) << 12) |
                                        (from_ascii_hex(buffer[1]) << 8)  |
                                        (from_ascii_hex(buffer[2]) << 4)  |
                                        (from_ascii_hex(buffer[3]));
                            data_o <= 0;
                            rw_o <= 0;
                            valid_o <= 1;
                        end
                    end
                end

                // current transaction specifies a write transaction
                if(state == WRITE) begin

                    // go to idle if anything doesn't make sense
                    if(byte_num < 8) begin
                        if(!is_ascii_hex(data_i)) state <= IDLE;
                    end

                    else if(byte_num == 8) begin
                        state <= IDLE;

                        // put data on the bus if the last byte looks good
                        if((data_i == 8'h0A) || (data_i == 8'h0D)) begin
                            addr_o <=   (from_ascii_hex(buffer[0]) << 12) |
                                        (from_ascii_hex(buffer[1]) << 8)  |
                                        (from_ascii_hex(buffer[2]) << 4)  |
                                        (from_ascii_hex(buffer[3]));
                            data_o <=   (from_ascii_hex(buffer[4]) << 12) |
                                        (from_ascii_hex(buffer[5]) << 8)  |
                                        (from_ascii_hex(buffer[6]) << 4)  |
                                        (from_ascii_hex(buffer[7]));
                            rw_o <= 1;
                            valid_o <= 1;
                        end
                    end
                end
            end
        end
    end

`ifdef FORMAL
        always @(posedge clk) begin
            // covers
            find_any_write_transaction: cover(rw_o == 1);
            find_any_read_transaction: cover(rw_o == 0);

            find_specific_write_transaction:
                cover(data_o == 16'h1234 && addr_o == 16'h5678 && rw_o == 1 && valid_o == 1);

            find_specific_read_transaction:
                cover(addr_o == 16'h1234 && rw_o == 0 && valid_o == 1);

            find_spacey_write_transaction:
                cover((rw_o == 1) && ($past(valid_i, 3) == 0));

            // asserts
            no_back_to_back_transactions:
                assert( ~(valid_o && $past(valid_o)) );

            no_invalid_states:
                assert(state == IDLE || state == READ || state == WRITE);

            byte_counter_only_increases:
                assert(byte_num == $past(byte_num) || byte_num == $past(byte_num) + 1 || byte_num == 0);
        end
`endif // FORMAL
endmodule

module logic_analyzer (
    input wire clk,

    // probes
    input wire data_valid_cc,
    input wire data_valid_cb,
    input wire [7:0] cam_data_in,
    input wire [15:0] cam_data_cb,
    input wire vs_lo_long,
    input wire hsync,
    input wire pclk_cam_in,

    // input port
    input wire [15:0] addr_i,
    input wire [15:0] data_i,
    input wire rw_i,
    input wire valid_i,

    // output port
    output reg [15:0] addr_o,
    output reg [15:0] data_o,
    output reg rw_o,
    output reg valid_o
    );
    localparam SAMPLE_DEPTH = 16384;
    localparam ADDR_WIDTH = $clog2(SAMPLE_DEPTH);

    reg [3:0] state;
    reg [15:0] trigger_loc;
    reg [1:0] trigger_mode;
    reg request_start;
    reg request_stop;
    reg [ADDR_WIDTH-1:0] read_pointer;
    reg [ADDR_WIDTH-1:0] write_pointer;

    reg trig;

    reg [ADDR_WIDTH-1:0] bram_addr;
    reg bram_we;

    localparam TOTAL_PROBE_WIDTH = 29;
    reg [TOTAL_PROBE_WIDTH-1:0] probes_concat;
    assign probes_concat = {pclk_cam_in, hsync, vs_lo_long, cam_data_cb, cam_data_in, data_valid_cb, data_valid_cc};

    logic_analyzer_controller #(.SAMPLE_DEPTH(SAMPLE_DEPTH)) la_controller (
        .clk(clk),

        // from register file
        .state(state),
        .trigger_loc(trigger_loc),
        .trigger_mode(trigger_mode),
        .request_start(request_start),
        .request_stop(request_stop),
        .read_pointer(read_pointer),
        .write_pointer(write_pointer),

        // from trigger block
        .trig(trig),

        // from block memory user port
        .bram_addr(bram_addr),
        .bram_we(bram_we)
    );

    logic_analyzer_fsm_registers #(
        .BASE_ADDR(0),
        .SAMPLE_DEPTH(SAMPLE_DEPTH)
        ) fsm_registers (
        .clk(clk),

        .addr_i(addr_i),
        .data_i(data_i),
        .rw_i(rw_i),
        .valid_i(valid_i),

        .addr_o(fsm_reg_trig_blk_addr),
        .data_o(fsm_reg_trig_blk_data),
        .rw_o(fsm_reg_trig_blk_rw),
        .valid_o(fsm_reg_trig_blk_valid),

        .state(state),
        .trigger_loc(trigger_loc),
        .trigger_mode(trigger_mode),
        .request_start(request_start),
        .request_stop(request_stop),
        .read_pointer(read_pointer),
        .write_pointer(write_pointer));

    reg [15:0] fsm_reg_trig_blk_addr;
    reg [15:0] fsm_reg_trig_blk_data;
    reg fsm_reg_trig_blk_rw;
    reg fsm_reg_trig_blk_valid;

    // trigger block
    trigger_block #(.BASE_ADDR(7)) trig_blk (
        .clk(clk),

        .data_valid_cc(data_valid_cc),
        .data_valid_cb(data_valid_cb),
        .cam_data_in(cam_data_in),
        .cam_data_cb(cam_data_cb),
        .vs_lo_long(vs_lo_long),
        .hsync(hsync),
        .pclk_cam_in(pclk_cam_in),

        .trig(trig),

        .addr_i(fsm_reg_trig_blk_addr),
        .data_i(fsm_reg_trig_blk_data),
        .rw_i(fsm_reg_trig_blk_rw),
        .valid_i(fsm_reg_trig_blk_valid),

        .addr_o(trig_blk_block_mem_addr),
        .data_o(trig_blk_block_mem_data),
        .rw_o(trig_blk_block_mem_rw),
        .valid_o(trig_blk_block_mem_valid));

    reg [15:0] trig_blk_block_mem_addr;
    reg [15:0] trig_blk_block_mem_data;
    reg trig_blk_block_mem_rw;
    reg trig_blk_block_mem_valid;

    // sample memory
    block_memory #(
        .BASE_ADDR(21),
        .WIDTH(TOTAL_PROBE_WIDTH),
        .DEPTH(SAMPLE_DEPTH)
        ) block_mem (
        .clk(clk),

        // input port
        .addr_i(trig_blk_block_mem_addr),
        .data_i(trig_blk_block_mem_data),
        .rw_i(trig_blk_block_mem_rw),
        .valid_i(trig_blk_block_mem_valid),

        // output port
        .addr_o(addr_o),
        .data_o(data_o),
        .rw_o(rw_o),
        .valid_o(valid_o),

        // BRAM itself
        .user_clk(clk),
        .user_addr(bram_addr),
        .user_din(probes_concat),
        .user_dout(),
        .user_we(bram_we));
endmodule
module logic_analyzer_controller (
    input wire clk,

    // from register file
    output reg [3:0] state,
    input wire [15:0] trigger_loc,
    input wire [1:0] trigger_mode,
    input wire request_start,
    input wire request_stop,
    output reg [ADDR_WIDTH-1:0] read_pointer,
    output reg [ADDR_WIDTH-1:0] write_pointer,

    // from trigger block
    input wire trig,

    // block memory user port
    output reg [ADDR_WIDTH-1:0] bram_addr,
    output reg bram_we
    );

    assign bram_addr = write_pointer;

    parameter SAMPLE_DEPTH= 0;
    localparam ADDR_WIDTH = $clog2(SAMPLE_DEPTH);

    /* ----- FIFO ----- */
    initial read_pointer = 0;
    initial write_pointer = 0;

    /* ----- FSM ----- */
    localparam IDLE = 0;
    localparam MOVE_TO_POSITION = 1;
    localparam IN_POSITION = 2;
    localparam CAPTURING = 3;
    localparam CAPTURED = 4;

    initial state = IDLE;

    // rising edge detection for start/stop requests
    reg prev_request_start;
    always @(posedge clk) prev_request_start <= request_start;

    reg prev_request_stop;
    always @(posedge clk) prev_request_stop <= request_stop;

    always @(posedge clk) begin
        // don't do anything to the FIFO unless told to

        if(state == IDLE) begin
            write_pointer <= 0;
            read_pointer <= 0;
            bram_we <= 0;

            if(request_start && ~prev_request_start) begin
                state <= MOVE_TO_POSITION;
            end
        end

        else if(state == MOVE_TO_POSITION) begin
            write_pointer <= write_pointer + 1;
            bram_we <= 1;

            if(write_pointer == trigger_loc) begin
                if(trig) state <= CAPTURING;
                else state <= IN_POSITION;
            end
        end

        else if(state == IN_POSITION) begin
            write_pointer <= (write_pointer + 1) % SAMPLE_DEPTH;
            read_pointer <= (read_pointer + 1) % SAMPLE_DEPTH;
            bram_we <= 1;
            if(trig) state <= CAPTURING;
        end

        else if(state == CAPTURING) begin
            if(write_pointer == read_pointer) begin
                bram_we <= 0;
                state <= CAPTURED;
            end

            else write_pointer <= (write_pointer + 1) % SAMPLE_DEPTH;
        end

        if(request_stop && ~prev_request_stop) state <= IDLE;
    end
endmodule
module logic_analyzer_fsm_registers(
    input wire clk,

    // input port
    input wire [15:0] addr_i,
    input wire [15:0] data_i,
    input wire rw_i,
    input wire valid_i,

    // output port
    output reg [15:0] addr_o,
    output reg [15:0] data_o,
    output reg rw_o,
    output reg valid_o,

    // registers
    input wire [3:0] state,
    output reg [15:0] trigger_loc,
    output reg [1:0] trigger_mode,
    output reg request_start,
    output reg request_stop,
    input wire [ADDR_WIDTH-1:0] read_pointer,
    input wire [ADDR_WIDTH-1:0] write_pointer
    );

    initial trigger_loc = 0;
    initial trigger_mode = 0;
    initial request_start = 0;
    initial request_stop = 0;

    parameter BASE_ADDR = 0;
    localparam MAX_ADDR = BASE_ADDR + 5;
    parameter SAMPLE_DEPTH = 0;
    parameter ADDR_WIDTH = $clog2(SAMPLE_DEPTH);

    always @(posedge clk) begin
        addr_o <= addr_i;
        data_o <= data_i;
        rw_o <= rw_i;
        valid_o <= valid_i;

        // check if address is valid
        if( (valid_i) && (addr_i >= BASE_ADDR) && (addr_i <= MAX_ADDR)) begin

            // reads
            if(!rw_i) begin
                case (addr_i)
                    BASE_ADDR + 0: data_o <= state;
                    BASE_ADDR + 1: data_o <= trigger_mode;
                    BASE_ADDR + 2: data_o <= trigger_loc;
                    BASE_ADDR + 3: data_o <= request_start;
                    BASE_ADDR + 4: data_o <= request_stop;
                    BASE_ADDR + 5: data_o <= read_pointer;
                    BASE_ADDR + 6: data_o <= write_pointer;
                endcase
            end

            // writes
            else begin
                case (addr_i)
                    BASE_ADDR + 1: trigger_mode <= data_i;
                    BASE_ADDR + 2: trigger_loc <= data_i;
                    BASE_ADDR + 3: request_start <= data_i;
                    BASE_ADDR + 4: request_stop <= data_i;
                endcase
            end
        end
    end


endmodule
module block_memory (
    input wire clk,

    // input port
    input wire [15:0] addr_i,
    input wire [15:0] data_i,
    input wire rw_i,
    input wire valid_i,

    // output port
    output reg [15:0] addr_o,
    output reg [15:0] data_o,
    output reg rw_o,
    output reg valid_o,

    // BRAM itself
    input wire user_clk,
    input wire [ADDR_WIDTH-1:0] user_addr,
    input wire [WIDTH-1:0] user_din,
    output reg [WIDTH-1:0] user_dout,
    input wire user_we);

    parameter BASE_ADDR = 0;
    parameter WIDTH = 0;
    parameter DEPTH = 0;
    localparam ADDR_WIDTH = $clog2(DEPTH);

    // ugly typecasting, but just computes ceil(WIDTH / 16)
    localparam N_BRAMS = int'($ceil(real'(WIDTH) / 16.0));
    localparam MAX_ADDR = BASE_ADDR + (DEPTH * N_BRAMS);

    // Port A of BRAMs
    reg [N_BRAMS-1:0][ADDR_WIDTH-1:0] addra = 0;
    reg [N_BRAMS-1:0][15:0] dina = 0;
    reg [N_BRAMS-1:0][15:0] douta;
    reg [N_BRAMS-1:0] wea = 0;

    // Port B of BRAMs
    reg [N_BRAMS-1:0][15:0] dinb;
    reg [N_BRAMS-1:0][15:0] doutb;
    assign dinb = user_din;

    // kind of a hack to part select from a 2d array that's been flattened to 1d
    reg [(N_BRAMS*16)-1:0] doutb_flattened;
    assign doutb_flattened = doutb;
    assign user_dout = doutb_flattened[WIDTH-1:0];

    // Pipelining
    reg [2:0][15:0] addr_pipe = 0;
    reg [2:0][15:0] data_pipe = 0;
    reg [2:0] valid_pipe = 0;
    reg [2:0] rw_pipe = 0;

    always @(posedge clk) begin
        addr_pipe[0] <= addr_i;
        data_pipe[0] <= data_i;
        valid_pipe[0] <= valid_i;
        rw_pipe[0] <= rw_i;

        addr_o <= addr_pipe[2];
        data_o <= data_pipe[2];
        valid_o <= valid_pipe[2];
        rw_o <= rw_pipe[2];

        for(int i=1; i<3; i=i+1) begin
            addr_pipe[i] <= addr_pipe[i-1];
            data_pipe[i] <= data_pipe[i-1];
            valid_pipe[i] <= valid_pipe[i-1];
            rw_pipe[i] <= rw_pipe[i-1];
        end

        // throw BRAM operations into the front of the pipeline
        wea <= 0;
        if( (valid_i) && (addr_i >= BASE_ADDR) && (addr_i <= MAX_ADDR)) begin
            wea[(addr_i - BASE_ADDR) % N_BRAMS]   <= rw_i;
            addra[(addr_i - BASE_ADDR) % N_BRAMS] <= (addr_i - BASE_ADDR) / N_BRAMS;
            dina[(addr_i - BASE_ADDR) % N_BRAMS]  <= data_i;
        end

        // pull BRAM reads from the back of the pipeline
        if( (valid_pipe[2]) && (addr_pipe[2] >= BASE_ADDR) && (addr_pipe[2] <= MAX_ADDR)) begin
            data_o <= douta[(addr_pipe[2] - BASE_ADDR) % N_BRAMS];
        end
    end

    // generate the BRAMs
    genvar i;
    generate
        for(i=0; i<N_BRAMS; i=i+1) begin
            dual_port_bram #(
                .RAM_WIDTH(16),
                .RAM_DEPTH(DEPTH)
                ) bram_full_width_i (

                // port A is controlled by the bus
                .clka(clk),
                .addra(addra[i]),
                .dina(dina[i]),
                .douta(douta[i]),
                .wea(wea[i]),

                // port B is exposed to the user
                .clkb(user_clk),
                .addrb(user_addr),
                .dinb(dinb[i]),
                .doutb(doutb[i]),
                .web(user_we));
        end
    endgenerate
endmodule
//  Xilinx True Dual Port RAM, Read First, Dual Clock
//  This code implements a parameterizable true dual port memory (both ports can read and write).
//  The behavior of this RAM is when data is written, the prior memory contents at the write
//  address are presented on the output port.  If the output data is
//  not needed during writes or the last read value is desired to be retained,
//  it is suggested to use a no change RAM as it is more power efficient.
//  If a reset or enable is not necessary, it may be tied off or removed from the code.

//  Modified from the xilinx_true_dual_port_read_first_2_clock_ram verilog language template.

module dual_port_bram #(
    parameter RAM_WIDTH = 0,
    parameter RAM_DEPTH = 0
    ) (
    input wire [$clog2(RAM_DEPTH-1)-1:0] addra,
    input wire [$clog2(RAM_DEPTH-1)-1:0] addrb,
    input wire [RAM_WIDTH-1:0] dina,
    input wire [RAM_WIDTH-1:0] dinb,
    input wire clka,
    input wire clkb,
    input wire wea,
    input wire web,
    output wire [RAM_WIDTH-1:0] douta,
    output wire [RAM_WIDTH-1:0] doutb
    );

    // The following code either initializes the memory values to a specified file or to all zeros to match hardware
    generate
        integer i;
        initial begin
            for (i = 0; i < RAM_DEPTH; i = i + 1)
                BRAM[i] = {RAM_WIDTH{1'b0}};
        end
    endgenerate

    reg [RAM_WIDTH-1:0] BRAM [RAM_DEPTH-1:0];
    reg [RAM_WIDTH-1:0] ram_data_a = {RAM_WIDTH{1'b0}};
    reg [RAM_WIDTH-1:0] ram_data_b = {RAM_WIDTH{1'b0}};

    always @(posedge clka) begin
        if (wea) BRAM[addra] <= dina;
        ram_data_a <= BRAM[addra];
    end

    always @(posedge clkb) begin
        if (web) BRAM[addrb] <= dinb;
        ram_data_b <= BRAM[addrb];
    end

    // Add a 2 clock cycle read latency to improve clock-to-out timing
    reg [RAM_WIDTH-1:0] douta_reg = {RAM_WIDTH{1'b0}};
    reg [RAM_WIDTH-1:0] doutb_reg = {RAM_WIDTH{1'b0}};

    always @(posedge clka) douta_reg <= ram_data_a;
    always @(posedge clkb) doutb_reg <= ram_data_b;

    assign douta = douta_reg;
    assign doutb = doutb_reg;
endmodule
module trigger_block (
    input wire clk,

    // probes
    input wire data_valid_cc,
    input wire data_valid_cb,
    input wire [7:0] cam_data_in,
    input wire [15:0] cam_data_cb,
    input wire vs_lo_long,
    input wire hsync,
    input wire pclk_cam_in,

    // trigger
    output reg trig,

    // input port
    input wire [15:0] addr_i,
    input wire [15:0] data_i,
    input wire rw_i,
    input wire valid_i,

    // output port
    output reg [15:0] addr_o,
    output reg [15:0] data_o,
    output reg rw_o,
    output reg valid_o);

    parameter BASE_ADDR = 0;
    localparam MAX_ADDR = 21;

    // trigger configuration registers
    // - each probe gets an operation and a compare register
    // - at the end we OR them all together. along with any custom probes the user specs

    reg [3:0] data_valid_cc_op = 0;
    reg data_valid_cc_arg = 0;
    reg data_valid_cc_trig;
    
    trigger #(.INPUT_WIDTH(1)) data_valid_cc_trigger (
        .clk(clk),
    
        .probe(data_valid_cc),
        .op(data_valid_cc_op),
        .arg(data_valid_cc_arg),
        .trig(data_valid_cc_trig));
    reg [3:0] data_valid_cb_op = 0;
    reg data_valid_cb_arg = 0;
    reg data_valid_cb_trig;
    
    trigger #(.INPUT_WIDTH(1)) data_valid_cb_trigger (
        .clk(clk),
    
        .probe(data_valid_cb),
        .op(data_valid_cb_op),
        .arg(data_valid_cb_arg),
        .trig(data_valid_cb_trig));
    reg [3:0] cam_data_in_op = 0;
    reg [7:0] cam_data_in_arg = 0;
    reg cam_data_in_trig;
    
    trigger #(.INPUT_WIDTH(8)) cam_data_in_trigger (
        .clk(clk),
    
        .probe(cam_data_in),
        .op(cam_data_in_op),
        .arg(cam_data_in_arg),
        .trig(cam_data_in_trig));
    reg [3:0] cam_data_cb_op = 0;
    reg [15:0] cam_data_cb_arg = 0;
    reg cam_data_cb_trig;
    
    trigger #(.INPUT_WIDTH(16)) cam_data_cb_trigger (
        .clk(clk),
    
        .probe(cam_data_cb),
        .op(cam_data_cb_op),
        .arg(cam_data_cb_arg),
        .trig(cam_data_cb_trig));
    reg [3:0] vs_lo_long_op = 0;
    reg vs_lo_long_arg = 0;
    reg vs_lo_long_trig;
    
    trigger #(.INPUT_WIDTH(1)) vs_lo_long_trigger (
        .clk(clk),
    
        .probe(vs_lo_long),
        .op(vs_lo_long_op),
        .arg(vs_lo_long_arg),
        .trig(vs_lo_long_trig));
    reg [3:0] hsync_op = 0;
    reg hsync_arg = 0;
    reg hsync_trig;
    
    trigger #(.INPUT_WIDTH(1)) hsync_trigger (
        .clk(clk),
    
        .probe(hsync),
        .op(hsync_op),
        .arg(hsync_arg),
        .trig(hsync_trig));
    reg [3:0] pclk_cam_in_op = 0;
    reg pclk_cam_in_arg = 0;
    reg pclk_cam_in_trig;
    
    trigger #(.INPUT_WIDTH(1)) pclk_cam_in_trigger (
        .clk(clk),
    
        .probe(pclk_cam_in),
        .op(pclk_cam_in_op),
        .arg(pclk_cam_in_arg),
        .trig(pclk_cam_in_trig));

   assign trig = data_valid_cc_trig || data_valid_cb_trig || cam_data_in_trig || cam_data_cb_trig || vs_lo_long_trig || hsync_trig || pclk_cam_in_trig;

    // perform register operations
    always @(posedge clk) begin
        addr_o <= addr_i;
        data_o <= data_i;
        rw_o <= rw_i;
        valid_o <= valid_i;

        if( (addr_i >= BASE_ADDR) && (addr_i <= BASE_ADDR + MAX_ADDR) ) begin

            // reads
            if(valid_i && !rw_i) begin
                case (addr_i)
                    BASE_ADDR + 0: data_o <= data_valid_cc_op;
                    BASE_ADDR + 1: data_o <= data_valid_cc_arg;
                    BASE_ADDR + 2: data_o <= data_valid_cb_op;
                    BASE_ADDR + 3: data_o <= data_valid_cb_arg;
                    BASE_ADDR + 4: data_o <= cam_data_in_op;
                    BASE_ADDR + 5: data_o <= cam_data_in_arg;
                    BASE_ADDR + 6: data_o <= cam_data_cb_op;
                    BASE_ADDR + 7: data_o <= cam_data_cb_arg;
                    BASE_ADDR + 8: data_o <= vs_lo_long_op;
                    BASE_ADDR + 9: data_o <= vs_lo_long_arg;
                    BASE_ADDR + 10: data_o <= hsync_op;
                    BASE_ADDR + 11: data_o <= hsync_arg;
                    BASE_ADDR + 12: data_o <= pclk_cam_in_op;
                    BASE_ADDR + 13: data_o <= pclk_cam_in_arg;
                endcase
            end

            // writes
            else if(valid_i && rw_i) begin
                case (addr_i)
                    BASE_ADDR + 0: data_valid_cc_op <= data_i;
                    BASE_ADDR + 1: data_valid_cc_arg <= data_i;
                    BASE_ADDR + 2: data_valid_cb_op <= data_i;
                    BASE_ADDR + 3: data_valid_cb_arg <= data_i;
                    BASE_ADDR + 4: cam_data_in_op <= data_i;
                    BASE_ADDR + 5: cam_data_in_arg <= data_i;
                    BASE_ADDR + 6: cam_data_cb_op <= data_i;
                    BASE_ADDR + 7: cam_data_cb_arg <= data_i;
                    BASE_ADDR + 8: vs_lo_long_op <= data_i;
                    BASE_ADDR + 9: vs_lo_long_arg <= data_i;
                    BASE_ADDR + 10: hsync_op <= data_i;
                    BASE_ADDR + 11: hsync_arg <= data_i;
                    BASE_ADDR + 12: pclk_cam_in_op <= data_i;
                    BASE_ADDR + 13: pclk_cam_in_arg <= data_i;
                endcase
            end
        end
    end
endmodule
module trigger (
    input wire clk,

    input wire [INPUT_WIDTH-1:0] probe,
    input wire [3:0] op,
    input wire [INPUT_WIDTH-1:0] arg,

    output reg trig);

    parameter INPUT_WIDTH = 0;

    localparam DISABLE = 0;
    localparam RISING = 1;
    localparam FALLING = 2;
    localparam CHANGING = 3;
    localparam GT = 4;
    localparam LT = 5;
    localparam GEQ = 6;
    localparam LEQ = 7;
    localparam EQ = 8;
    localparam NEQ = 9;

    reg [INPUT_WIDTH-1:0] probe_prev = 0;
    always @(posedge clk) probe_prev <= probe;

    always @(*) begin
        case (op)
            RISING :    trig = (probe > probe_prev);
            FALLING :   trig = (probe < probe_prev);
            CHANGING :  trig = (probe != probe_prev);
            GT:         trig = (probe > arg);
            LT:         trig = (probe < arg);
            GEQ:        trig = (probe >= arg);
            LEQ:        trig = (probe <= arg);
            EQ:         trig = (probe == arg);
            NEQ:        trig = (probe != arg);
            default:    trig = 0;
        endcase
    end
endmodule

module bridge_tx (
    input wire clk,

    input wire [15:0] data_i,
    input wire rw_i,
    input wire valid_i,

    output reg [7:0] data_o,
    output reg start_o,
    input wire done_i);

    function [7:0] to_ascii_hex;
        // convert a number from 0-15 into the corresponding ascii char
        input [3:0] n;
        to_ascii_hex = (n < 10) ? (n + 8'h30) : (n + 8'h41 - 'd10);
    endfunction

    localparam PREAMBLE = "D";
    localparam CR = 8'h0D;
    localparam LF = 8'h0A;

    reg busy = 0;
    reg [15:0] buffer = 0;
    reg [3:0] count = 0;

    assign start_o = busy;

    always @(posedge clk) begin
        // idle until valid read transaction arrives on bus
        if (!busy) begin
            if (valid_i && !rw_i) begin
                busy <= 1;
                buffer <= data_i;
            end
        end

        if (busy) begin
            // uart module is done transmitting a byte
            if(done_i) begin
                count <= count + 1;

                // message has been transmitted
                if (count > 5) begin
                    count <= 0;

                    // go back to idle or transmit next message
                    if (valid_i && !rw_i) buffer <= data_i;
                    else busy <= 0;
                end
            end
        end
    end

    always @(*) begin
        case (count)
            0: data_o = PREAMBLE;
            1: data_o = to_ascii_hex(buffer[15:12]);
            2: data_o = to_ascii_hex(buffer[11:8]);
            3: data_o = to_ascii_hex(buffer[7:4]);
            4: data_o = to_ascii_hex(buffer[3:0]);
            5: data_o = CR;
            6: data_o = LF;
            default: data_o = 0;
        endcase
    end
endmodule
module uart_tx (
	input wire clk,

	input wire [7:0] data_i,
	input wire start_i,
	output reg done_o,

	output reg tx);

	// this module supports only 8N1 serial at a configurable baudrate
	parameter CLOCKS_PER_BAUD = 0;
	reg [$clog2(CLOCKS_PER_BAUD)-1:0] baud_counter = 0;

	reg [8:0] buffer = 0;
	reg [3:0] bit_index = 0;

	initial done_o = 1;
	initial tx = 1;

	always @(posedge clk) begin
		if (start_i && done_o) begin
			baud_counter <= CLOCKS_PER_BAUD - 1;
			buffer <= {1'b1, data_i};
			bit_index <= 0;
			done_o <= 0;
			tx <= 0;
		end

		else if (!done_o) begin
			baud_counter <= baud_counter - 1;
			done_o <= (baud_counter == 1) && (bit_index == 9);

			// a baud period has elapsed
			if (baud_counter == 0) begin
				baud_counter <= CLOCKS_PER_BAUD - 1;

				// clock out another bit if there are any left
				if (bit_index < 9) begin
					tx <= buffer[bit_index];
					bit_index <= bit_index + 1;
				end

				// byte has been sent, send out next one or go to idle
				else begin
					if(start_i) begin
						buffer <= {1'b1, data_i};
						bit_index <= 0;
						tx <= 0;
					end

					else done_o <= 1;
				end
			end
		end
	end
endmodule
`default_nettype wire