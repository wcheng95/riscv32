// Architectural regression testbench for the independent rv32_core.
`timescale 1ns/1ps

module rv32i_own_tb;
    reg clk = 0;
    reg resetn = 0;
    always #5 clk = ~clk;

    wire trap, mem_valid, mem_instr, mem_ready;
    wire [31:0] mem_addr, mem_wdata, mem_rdata;
    wire [3:0] mem_wstrb;

    integer lab = -1;
    integer cycles = 0;
    integer stores = 0;
    integer fetches = 0;
    integer i;
    integer expected_stores;
    reg completed = 0;
    reg [31:0] expected [0:7];
    reg [31:0] expected_addr;

    rv32_core cpu (
        .clk(clk),
        .resetn(resetn),
        .trap(trap),
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata)
    );

    ram main_ram (
        .clk(clk), .resetn(resetn),
        .mem_valid(mem_valid),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata)
    );

    initial begin
        if (!$value$plusargs("lab=%d", lab) ||
            !((lab >= 0 && lab <= 6) || lab == 8 || lab == 9 || lab == 13))
            $fatal(1, "Use +lab=0..6, 8, 9, or 13");

        if (lab == 0) begin
            expected_stores = 1;
            expected[0] = 12;
        end else if (lab == 1) begin
            expected_stores = 4;
            expected[0] = 0;
            expected[1] = 32'hfffffffd;
            expected[2] = 2;
            expected[3] = 5;
        end else if (lab == 2) begin
            expected_stores = 3;
            expected[0] = 12;
            expected[1] = 32'h28;
            expected[2] = 32'h10;
        end else if (lab == 3) begin
            expected_stores = 4;
            expected[0] = 32'h7fffffff;
            expected[1] = 32'hffffffff;
            expected[2] = 1;
            expected[3] = 1;
        end else if (lab == 4) begin
            expected_stores = 8;
            expected[0] = 32'h80ff7f01;
            expected[1] = 32'h0000007f;
            expected[2] = 32'h000000ff;
            expected[3] = 32'hffff80ff;
            expected[4] = 32'h000080ff;
            expected[5] = 32'h7f010113;
        end else if (lab == 5) begin
            expected_stores = 4;
            expected[0] = 32'h24;
            expected[1] = 32'h38;
            expected[2] = 32'hffffffff;
            expected[3] = 1;
        end else if (lab == 6) begin
            expected_stores = 2;
            expected[0] = 42;
            expected[1] = 43;
        end else if (lab == 8) begin
            expected_stores = 2;
            expected[0] = 17;
            expected[1] = 337;
        end else if (lab == 9) begin
            expected_stores = 0;
        end else begin
            expected_stores = 2;
            expected[0] = 15;
            expected[1] = 16;
        end

        repeat (10) @(negedge clk);
        resetn = 1;
    end

    always @(posedge clk) begin
        if (resetn && mem_valid && mem_ready) begin
            if (mem_instr)
                fetches <= fetches + 1;

            // Lab13 uses the stack at 0x1008..0x1fff. Those writes are not
            // result-area stores and are ignored by the result checker.
            if (|mem_wstrb &&
                !(lab == 13 && mem_addr >= 32'h1008 && mem_addr < 32'h2000)) begin
                if (lab == 4 && stores >= 5)
                    expected_addr = (stores == 7) ? 32'h1018 : 32'h1014;
                else
                    expected_addr = 32'h1000 + stores * 4;

                if ((lab == 0 && stores >= 1) ||
                    (lab == 1 && stores >= 4) ||
                    (lab == 2 && stores >= 3) ||
                    (lab == 3 && stores >= 4) ||
                    (lab == 4 && stores >= 8) ||
                    (lab == 5 && stores >= 4) ||
                    (lab == 6 && stores >= 2) ||
                    (lab == 8 && stores >= 2) ||
                    (lab == 13 && stores >= 2) ||
                    mem_addr !== expected_addr ||
                    (lab == 4 && stores == 5
                        ? (mem_wstrb !== 4'b0010 || mem_wdata[15:8] !== 8'h01)
                        : lab == 4 && stores == 6
                        ? (mem_wstrb !== 4'b1100 || mem_wdata[31:16] !== 16'h7f01)
                        : (mem_wstrb !== 4'b1111 ||
                           mem_wdata !== expected[lab == 4 && stores == 7 ? 5 : stores])))
                    $fatal(1, "FAIL: store #%0d addr=%08x data=%08x strb=%b",
                           stores, mem_addr, mem_wdata, mem_wstrb);

                if (stores == expected_stores - 1)
                    completed <= 1;
                stores <= stores + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (resetn) begin
            cycles <= cycles + 1;

            if (trap) begin
                if (lab == 9) begin
                    if (stores != 0)
                        $fatal(1, "FAIL: store before expected trap");
                    $display("PASS: own core Lab09 expected trap cycles=%0d", cycles);
                    $finish;
                end else begin
                    $fatal(1, "FAIL: unexpected trap lab=%0d cycle=%0d", lab, cycles);
                end
            end

            if (completed) begin
                if (lab == 4 && (main_ram.memory[1029] !== 32'h7f010113 ||
                                 main_ram.memory[1030] !== 32'h7f010113))
                    $fatal(1, "FAIL: Lab04 byte lanes / reloaded word");

                for (i = 0;
                     i < (lab == 4 ? 5 : (lab == 13 ? 2 : expected_stores));
                     i = i + 1)
                    if (main_ram.memory[1024+i] !== expected[i])
                        $fatal(1, "FAIL: RAM[%0d] got %08x expected %08x",
                               i, main_ram.memory[1024+i], expected[i]);

                $display("PASS: own core lab%0d cycles=%0d fetches=%0d",
                         lab, cycles, fetches);
                $finish;
            end

            if (lab == 9 && completed)
                $fatal(1, "FAIL: Lab09 completed without trap");

            if (cycles > 3000)
                $fatal(1, "FAIL: own-core timeout lab=%0d", lab);
        end
    end
endmodule
