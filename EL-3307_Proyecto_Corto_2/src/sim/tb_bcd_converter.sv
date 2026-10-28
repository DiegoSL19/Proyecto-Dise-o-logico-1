module tb_bcd_converter;
    timeunit 1ns;
    timeprecision 1ps;

    logic [9:0] input_bin;
    logic [11:0] output_bcd;
    int unsigned total_tests;
    int unsigned errors;

    bcd_converter #(
        .N(10),
        .M(12)
    ) dut (
        .input_bin  (input_bin),
        .output_bcd (output_bcd)
    );

    task automatic check_conversion (
        input logic [9:0] binary_value,
        input logic [11:0] expected_bcd
    );
        input_bin = binary_value;
        #1ns; // Esperar la inicializacion y la lectura combinacional de la ROM.
        total_tests += 1;

        if (output_bcd === expected_bcd)
            $display("PASS: binario=%0d -> BCD=%03h", binary_value, output_bcd);
        else begin
            errors += 1;
            $error("FAIL: binario=%0d -> BCD=%03h; esperado=%03h",
                   binary_value, output_bcd, expected_bcd);
        end
    endtask

    initial begin
        input_bin = 10'd0;
        total_tests = 0;
        errors = 0;

        check_conversion(10'd0,    12'h000);
        check_conversion(10'd1,    12'h001);
        check_conversion(10'd9,    12'h009);
        check_conversion(10'd10,   12'h010);
        check_conversion(10'd45,   12'h045);
        check_conversion(10'd99,   12'h099);
        check_conversion(10'd100,  12'h100);
        check_conversion(10'd123,  12'h123);
        check_conversion(10'd377,  12'h377);
        check_conversion(10'd500,  12'h500);
        check_conversion(10'd999,  12'h999);
        check_conversion(10'd1000, 12'h000);

        $display("Total de pruebas: %0d", total_tests);
        $display("Errores: %0d", errors);
        if (errors == 0)
            $display("Resultado general: PASS");
        else
            $display("Resultado general: FAIL");
        $finish;
    end

endmodule
