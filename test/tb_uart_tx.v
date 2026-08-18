`default_nettype none
`timescale 1ns / 1ps

/* Standalone testbench for uart_tx: instantiates the module directly, with
   its real port names, so test_uart_tx.py can drive/observe it without
   going through the tt_um chip-level pin mapping. */
module tb_uart_tx ();

  initial begin
    $dumpfile("tb_uart_tx.fst");
    $dumpvars(0, tb_uart_tx);
    #1;
  end

  reg clk;
  reg rst_n;
  reg [7:0] data_i;
  reg valid_i;
  wire ready_o;
  wire message_o;

  uart_tx dut (
      .clk       (clk),
      .rst_n     (rst_n),
      .data_i    (data_i),
      .valid_i   (valid_i),
      .ready_o   (ready_o),
      .message_o (message_o)
  );

endmodule
