module uart_tx #(
    parameter F_CLK = 50_000_000,
    parameter R_BAUD = 115_200
) (
    input logic clk,
    input logic rst_n,
    input logic [7:0] data_i,
    input logic valid_i,
    // Make char one object, accept multiple chars per transmission (maybe)
    output logic ready_o,
    output logic message_o
);
// States
typedef enum logic { Idle, Tx } state_t;
state_t state_d, state_q;

// Uncoded and Coded data
logic [7:0] data_d, data_q;
logic [10:0] frame_d, frame_q;

// Transmission bit and frame index
logic [3:0] idx_d, idx_q;
logic txbit_d, txbit_q;
assign message_o = txbit_q;

// BUG: if last index is not reset (because propagation of the index happens on slow clock),
// then another valid signal will put the state into Tx but immediately back because the idx has not reset yet,
// dropping an entire transmission.

// Ready?
logic ready_q, ready_d;
assign ready_o = ready_q;

// Slower clock division
logic [63:0] clk_baud_d, clk_baud_q;
logic clk_baud;

localparam LAST_FRAME_IDX = 4'd10;

// Combo FF for a few signals
always_ff @( posedge clk, negedge rst_n ) begin : Transmit
    if (!rst_n) begin
        ready_q <= 'b0;
        state_q <= Idle;
        data_q <= 'b0;
        frame_q <= 'b0;
    end else begin
        ready_q <= ready_d;
        state_q <= state_d;
        data_q <= data_d;
        frame_q <= frame_d;
    end
end

// The slow case flipflop should contain the done, txbit

always_comb begin
    case (state_q)
        Idle: begin
            state_d = Idle;
            ready_d = 'b1;
            data_d = data_q;
            frame_d = frame_q;

            if (valid_i) begin
                state_d = Tx;
                data_d = data_i;
            end
            
        end
        Tx: begin
            state_d = Tx;
            ready_d = 'b0;
            data_d = data_q;
            frame_d = create_frame(data_q);

            if (idx_q >= LAST_FRAME_IDX) begin
                state_d = Idle;
                ready_d = 'b1;
            end
        end

        default: begin
            state_d = state_q;
            ready_d = ready_q;
            data_d = data_q;
            frame_d = frame_q;

        end
    endcase
end


function automatic logic[10:0] create_frame (byte data_q);
    logic parity = 0;
    for (int i = 0; i<8; i++) begin
            parity = ^data_q;
    end
    return {1'b1, parity,data_q,1'b0};    
endfunction


// Clock division to reach the desired baud rate
localparam div = F_CLK/R_BAUD;
always_ff @( posedge clk, negedge rst_n ) begin : ClkDivFF
    if (!rst_n)begin
        clk_baud_q <= 'b0;
    end else begin
        clk_baud_q <= clk_baud_d;
    end
end

always_comb begin : ClkDivComb
    clk_baud_d = clk_baud_q + 1;
    if (clk_baud_d == div)begin
        clk_baud_d = 'b0;
    end
    if (clk_baud_d >= div/2) begin
        clk_baud = 1'b1;
    end else begin
        clk_baud = 1'b0;
    end
end


// The actual Transmission
always_ff @( negedge rst_n, posedge clk_baud ) begin : UART_FF
    if (!rst_n)begin
        txbit_q <= 'b1;
        idx_q <= 'b0;
    end else begin
        txbit_q <= txbit_d;
        idx_q <= idx_d;
    end
end
always_comb begin : UART_comb
    case (state_q)
        Idle: begin
            idx_d = 'b0;
            txbit_d = 'b1;
        end 
        Tx: begin
            idx_d = idx_q;
            txbit_d = frame_q[idx_q];
            // CAREFUL: only works because the start bit is always 0!
            if (idx_q < LAST_FRAME_IDX) begin
                idx_d = idx_q+1;
            end else begin
                idx_d = 'b0;
            end
            
        end
        default: begin
            idx_d = idx_q;
            txbit_d = txbit_q;
        end
    endcase
end
endmodule