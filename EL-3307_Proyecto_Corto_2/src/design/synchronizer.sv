module synchronizer (
    input  logic       clk,
    input  logic       reset,
    input  logic [3:0] async_in,
    output logic [3:0] sync_out
);

    logic [3:0] sync_stage1;

    always_ff @(posedge clk) begin
        if (reset) begin
            sync_stage1 <= 4'b1111;
            sync_out <= 4'b1111;
        end else begin
            sync_stage1 <= async_in;
            sync_out <= sync_stage1;
        end
    end

endmodule
