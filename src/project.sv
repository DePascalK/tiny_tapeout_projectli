/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_depascalk (
    input  logic [7:0] ui_in,    // Dedicated inputs
    output logic [7:0] uo_out,   // Dedicated outputs
    input  logic [7:0] uio_in,   // IOs: Input path
    output logic [7:0] uio_out,  // IOs: Output path
    output logic [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  logic       ena,      // always 1 when the design is powered, so you can ignore it
    input  logic       clk,      // clock
    input  logic       rst_n     // reset_n - low to reset
);

  logic ready_uart;
  uart_tx uart_tx_inst (
      .clk       (clk),
      .rst_n     (rst_n),
      .data_i    (ui_in),      // ui_in[7:0] carries the byte to send
      .valid_i   (uio_in[0]),  // pulse uio_in[0] high for one clk to start a transmission
      .ready_o   (ready_uart),
      .message_o (uo_out[0])   // serial line
  );

  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out[7:1] = '0;
  assign uio_out      = {8'b0};
  assign uio_oe       = 8'b0000_0001;  // uio[0] is an output (ready_o), rest are inputs

  // List all unused inputs to prevent warnings
  logic _unused;
  assign _unused = &{ena, uio_in[7:1], 1'b0};

endmodule