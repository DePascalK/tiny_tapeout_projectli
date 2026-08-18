module word_to_uart #(
    parameter F_CLK = 50_000_000,
    parameter R_BAUD = 115_200
) (
    input logic clk,
    input logic rst_n,
    input logic [31:0] word_i,
    input logic valid_i,
    // Make char one object, accept multiple chars per transmission (maybe)
    output logic ready_o,
    output logic message_thru
);

// incoming word and length count
logic [31:0] wordsr_d, wordsr_q;
logic [2:0] cnt_d, cnt_q;

// If the queue has items in it, this module is not ready but has valid data
assign ready_o = (cnt_q == 'b0);
logic valid_byte;
assign valid_byte = (cnt_q != 'b0);


// Valid output byte and output byte
typedef logic [7:0] byte_t;

logic [7:0] byte_o;
assign byte_o = wordsr_q[7:0];

// logic valid_byte_d,valid_byte_q;

// Submodule is ready to accept byte
logic ready_byte;

// // Queue
// byte_t queuebyte [$];

uart_tx  #(
    .F_CLK      (F_CLK),
    .R_BAUD     (R_BAUD)
    )
    uart_tx_word(
    .clk        (clk),
    .rst_n      (rst_n),
    .data_i     (byte_o),
    .valid_i    (valid_byte),
    // Make char one object, accept multiple chars per transmission (maybe)
    .ready_o    (ready_byte),
    .message_o  (message_thru)
);

always_ff @(posedge clk, negedge rst_n) begin : AllFF
    if (!rst_n) begin
        wordsr_q <= 'b0;
        cnt_q <= 'b0;
    end else begin
        wordsr_q <= wordsr_d;
        cnt_q <= cnt_d;
    end
end

always_comb begin : AllComb
    // If this module is ready and a valid word is present, receive a new word
    wordsr_d = wordsr_q;
    cnt_d = cnt_q;
    if (valid_i & ready_o)begin
        wordsr_d = word_i;
        cnt_d = 3'd4;
    end else if (valid_byte && ready_byte) begin
        wordsr_d = {8'b0, wordsr_q[31:8]};
        cnt_d = cnt_q - 'd1;
    end
end
endmodule