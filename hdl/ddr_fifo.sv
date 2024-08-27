`timescale 1ns / 1ps
`default_nettype none

module ddr_fifo
  #(parameter DEPTH=512, 
    parameter PROGFULL_DEPTH=12)
  (
   input wire 		sender_rst,
   input wire 		sender_clk,
   input wire 		sender_axis_tvalid,
   output logic 	sender_axis_tready,
   input wire [127:0] 	sender_axis_tdata,
   input wire 		sender_axis_tuser,
   output logic 	sender_axis_prog_full,

   input wire 		receiver_clk,
   output logic 	receiver_axis_tvalid,
   input wire 		receiver_axis_tready,
   output logic [127:0] receiver_axis_tdata,
   output logic 	receiver_axis_tuser,
   output logic 	receiver_axis_prog_empty
   );

   xpm_fifo_axis #(
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CDC_SYNC_STAGES(2),            // DECIMAL
      .CLOCKING_MODE("independent_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .FIFO_DEPTH(DEPTH),              // DECIMAL
      .FIFO_MEMORY_TYPE("auto"),      // String
      .PACKET_FIFO("false"),          // String
      .PROG_EMPTY_THRESH(10),         // DECIMAL
      .PROG_FULL_THRESH(DEPTH-PROGFULL_DEPTH),          // DECIMAL
      .RELATED_CLOCKS(0),             // DECIMAL
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .TDATA_WIDTH(128),               // DECIMAL
      .TUSER_WIDTH(1),                // DECIMAL
      .USE_ADV_FEATURES("0202")      // String
   )
   xpm_fifo_axis_inst (
      .m_axis_tdata(receiver_axis_tdata),             // TDATA_WIDTH-bit output: TDATA: The primary payload that is
                                               // used to provide the data that is passing across the
                                               // interface. The width of the data payload is an integer number
                                               // of bytes.

      .m_axis_tuser(receiver_axis_tuser),             // TUSER_WIDTH-bit output: TUSER: The user-defined sideband
                                               // information that can be transmitted alongside the data
                                               // stream.

      .m_axis_tvalid(receiver_axis_tvalid),           // 1-bit output: TVALID: Indicates that the master is driving a
                                               // valid transfer. A transfer takes place when both TVALID and
                                               // TREADY are asserted

      .prog_empty_axis(receiver_axis_prog_empty),       // 1-bit output: Programmable Empty- This signal is asserted
                                               // when the number of words in the FIFO is less than or equal to
                                               // the programmable empty threshold value. It is de-asserted
                                               // when the number of words in the FIFO exceeds the programmable
                                               // empty threshold value.

      .prog_full_axis(sender_axis_prog_full),         // 1-bit output: Programmable Full: This signal is asserted when
                                               // the number of words in the FIFO is greater than or equal to
                                               // the programmable full threshold value. It is de-asserted when
                                               // the number of words in the FIFO is less than the programmable
                                               // full threshold value.

      .s_axis_tready(sender_axis_tready),           // 1-bit output: TREADY: Indicates that the slave can accept a
                                               // transfer in the current cycle.


      .m_aclk(receiver_clk),                         // 1-bit input: Master Interface Clock: All signals on master
                                               // interface are sampled on the rising edge of this clock.

      .m_axis_tready(receiver_axis_tready),           // 1-bit input: TREADY: Indicates that the slave can accept a
                                               // transfer in the current cycle.

      .s_aclk(sender_clk),                         // 1-bit input: Slave Interface Clock: All signals on slave
                                               // interface are sampled on the rising edge of this clock.

      .s_aresetn(~sender_rst),                   // 1-bit input: Active low asynchronous reset.
      .s_axis_tdata(sender_axis_tdata),             // TDATA_WIDTH-bit input: TDATA: The primary payload that is
                                               // used to provide the data that is passing across the
                                               // interface. The width of the data payload is an integer number
                                               // of bytes.

      .s_axis_tuser(sender_axis_tuser),             // TUSER_WIDTH-bit input: TUSER: The user-defined sideband
                                               // information that can be transmitted alongside the data
                                               // stream.

      .s_axis_tvalid(sender_axis_tvalid)            // 1-bit input: TVALID: Indicates that the master is driving a
                                               // valid transfer. A transfer takes place when both TVALID and
                                               // TREADY are asserted

   );

   // End of xpm_fifo_axis_inst instantiation
				
   

endmodule

   


`default_nettype wire
