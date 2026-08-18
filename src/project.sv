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

    // Make the code testbench-friendly
    logic ready_uart;
    logic message_out;
    logic valid_word;
    parameter WORD = 32'b0001_1010_0010_1011_0011_1100_0100_1101;

    // Instantiate uart word transmission
    word_to_uart #(
        .F_CLK      (50_000_000),
        .R_BAUD     (115_200)
    ) word_to_uart_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .word_i     (WORD),
        .valid_i    (valid_word),  // pulse uio_in[0] high for one clk to start a transmission
        .ready_o    (ready_uart),
        .message_thru (message_out)
    );

    // All output pins must be assigned. If not used, assign to 0.
    assign uo_out[7:0]  = {6'b0, ready_uart,message_out};
    assign uio_out      = {8'b0};
    assign uio_oe       = 8'b0000_0010;  // uio[1] is an output (ready_o), rest are inputs

    assign valid_word = ui_in[0];
    // List all unused inputs to prevent warnings
    logic _unused;
    assign _unused = &{ena, ui_in[7:1], uio_in[7:0]};

endmodule