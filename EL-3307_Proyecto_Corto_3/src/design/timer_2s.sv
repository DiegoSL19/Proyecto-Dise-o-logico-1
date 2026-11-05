module timer_2s #(
    parameter logic [25:0] TIMER_CYCLES = 26'd54_000_000
) (
    input  logic clk,
    input  logic reset,
    input  logic clear,
    input  logic enable,
    output logic done
);

    logic [25:0] count;

    always_ff @(posedge clk) begin
        if (reset) begin
            count <= 26'd0;
            done <= 1'b0;
        end else if (clear) begin
            count <= 26'd0;
            done <= 1'b0;
        end else if (enable && !done) begin
            if (count == TIMER_CYCLES - 26'd1)
                done <= 1'b1;
            else
                count <= count + 26'd1;
        end
    end

endmodule
