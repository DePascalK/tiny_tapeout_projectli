module uart_tx #(
    parameter F_CLK = 50_000_000,
    parameter R_BAUD = 115_200
) (
    // Inputs
    input logic clk,
    input logic rst_n,
    input logic [7:0] data_i,
    input logic valid_i,
    // Outputs
    output logic ready_o,
    output logic message_o
);
// States
typedef enum logic { Idle, Tx } state_t;
state_t state_d, state_q;

// Coded data for shift register
logic [10:0] frame_d, frame_q;
assign message_o = frame_q[0];

// Frame index
logic [3:0] idx_d, idx_q;

// Ready?
logic ready_q, ready_d;
assign ready_o = ready_q;

// Clock division and register width magic
localparam int DIV = F_CLK/R_BAUD;
localparam int DIV_BITS = $clog2(DIV);
localparam logic [DIV_BITS-1:0] DIV_MAX = DIV_BITS'(DIV-1);
logic [DIV_BITS-1:0] baudcnt;

// Ticking the baud clock
logic baud_tick; 
assign baud_tick = (baudcnt == DIV_MAX);

localparam LAST_FRAME_IDX = 4'd10;

// Combo FF for all
always_ff @( posedge clk, negedge rst_n ) begin : TransmitFF
    if (!rst_n) begin
        ready_q <= 'b1;
        state_q <= Idle;
        frame_q <= ~11'b0;
        idx_q <= 'b0;
    end else begin
        ready_q <= ready_d;
        state_q <= state_d;
        frame_q <= frame_d;
        idx_q <= idx_d;
    end
end

always_comb begin
    case (state_q)
        Idle: begin
            state_d = state_q;
            ready_d = ready_q;
            frame_d = frame_q;
            idx_d = idx_q;

            // Accepting Transmission (quasi-state)
            if (valid_i) begin
                state_d = Tx;
                frame_d = create_frame(data_i);
                ready_d = 'b0;
            end
        end
        Tx: begin
            state_d = state_q;
            ready_d = ready_q;
            frame_d = frame_q;
            idx_d = idx_q;

            if (baud_tick) begin
                frame_d = {1'b1, frame_q[10:1]};
                idx_d = idx_q + 1;

                // Finishing transmission (quasi-state)
                if (idx_q >= LAST_FRAME_IDX) begin
                    state_d = Idle;
                    ready_d = 'b1;
                    idx_d = 'b0;
                end
            end
        end
        default: begin
            state_d = state_q;
            ready_d = ready_q;
            frame_d = frame_q;
            idx_d = idx_q;
        end
    endcase
end

// Function to code a frame wide-sense systematic encoding btw
function automatic logic[10:0] create_frame (logic[7:0] data);
    logic parity;
    parity = ^data;
    create_frame = {1'b1, parity, data, 1'b0};
endfunction

// Count up for baud ticks
always_ff @( posedge clk, negedge rst_n ) begin : BaudCountFF
    if (!rst_n)                 baudcnt <= 'b0;
    else if (state_q == Idle)   baudcnt <= 'b0;
    else if (baud_tick)         baudcnt <= 'b0;
    else                        baudcnt <= baudcnt + 1;
end

endmodule