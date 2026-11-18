module subtractor (
    input  logic       clk,
    input  logic       reset,
    input  logic       calculate,
    input  logic [9:0] operand_a,
    input  logic [9:0] operand_b,
    output logic [9:0] magnitude,
    output logic       negative,
    output logic       result_valid
);

    logic [10:0] a_ext;
    logic [10:0] b_ext;
    logic [11:0] diff_ab_ext;
    logic [11:0] diff_ba_ext;
    logic [10:0] magnitude_next;
    logic        negative_next;

    always_comb begin
        a_ext = {1'b0, operand_a};
        b_ext = {1'b0, operand_b};

        diff_ab_ext = {1'b0, a_ext} + {1'b0, ~b_ext} + 12'd1;
        diff_ba_ext = {1'b0, b_ext} + {1'b0, ~a_ext} + 12'd1;

        if (diff_ab_ext[11]) begin
            magnitude_next = diff_ab_ext[10:0];
            negative_next = 1'b0;
        end else begin
            magnitude_next = diff_ba_ext[10:0];
            negative_next = 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            magnitude <= 10'd0;
            negative <= 1'b0;
            result_valid <= 1'b0;
        end else if (calculate) begin
            magnitude <= magnitude_next[9:0];
            negative <= negative_next;
            result_valid <= 1'b1;
        end else begin
            result_valid <= 1'b0;
        end
    end

endmodule
