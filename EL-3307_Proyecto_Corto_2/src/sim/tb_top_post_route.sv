`timescale 1ns/1ps

module tb_top_post_route;
    localparam realtime HALF_PERIOD_NS = 1000.0 / 54.0;

    logic clk;
    logic reset_n;
    logic [3:0] rows;
    wire [3:0] columns;
    wire [3:0] an;
    wire [7:0] sseg;
    int unsigned errors;

    top dut (
        .clk     (clk),
        .reset_n (reset_n),
        .rows    (rows),
        .columns (columns),
        .an      (an),
        .sseg    (sseg)
    );

    initial begin
        clk = 1'b0;
        forever #(HALF_PERIOD_NS) clk = ~clk;
    end

    initial begin
        $sdf_annotate("proyecto_post_route.sdf", dut);
    end

    initial begin
        errors = 0;
        reset_n = 1'b0;
        rows = 4'b1111;

        // Permitir la propagacion del reset en la netlist con retardos.
        repeat (32) @(posedge clk);
        @(negedge clk);
        if (columns !== 4'b1110) begin
            errors += 1;
            $display("FAIL reset: columns=%b; esperado=1110", columns);
        end
        if (an !== 4'b0001) begin
            errors += 1;
            $display("FAIL reset: an=%b; esperado=0001", an);
        end
        if (sseg !== 8'b01111110) begin
            errors += 1;
            $display("FAIL reset: sseg=%b; esperado=01111110", sseg);
        end

        reset_n = 1'b1;
        repeat (32) @(posedge clk);
        repeat (64) begin
            @(negedge clk);
            if ($isunknown(columns)) begin
                errors += 1;
                $display("FAIL: columns contiene X/Z: %b", columns);
            end
            if ($isunknown(an)) begin
                errors += 1;
                $display("FAIL: an contiene X/Z: %b", an);
            end
            if ($isunknown(sseg)) begin
                errors += 1;
                $display("FAIL: sseg contiene X/Z: %b", sseg);
            end
        end

        $display("Errores: %0d", errors);
        if (errors == 0)
            $display("Resultado general POST-P&R: PASS");
        else
            $display("Resultado general POST-P&R: FAIL");
        $finish;
    end
endmodule
