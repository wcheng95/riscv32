// Shared PicoRV32 simulation machine for all early RV32I labs.
`timescale 1ns/1ps
module riscv32_tb;
    reg clk = 0, resetn = 0;
    always #5 clk = ~clk;
    wire trap, mem_valid, mem_instr, mem_ready;
    wire [31:0] mem_addr, mem_wdata, mem_rdata;
    wire [3:0] mem_wstrb;
    integer lab = -1, cycles = 0, stores = 0, fetches = 0;
    integer i;
    reg completed = 0;
    reg [31:0] expected [0:7];
    integer expected_stores;
    reg [31:0] expected_addr;

    picorv32 #(
        .COMPRESSED_ISA(0), .ENABLE_MUL(0), .ENABLE_DIV(0),
        .ENABLE_PCPI(0), .ENABLE_IRQ(0), .PROGADDR_RESET(32'h0)
    ) cpu (
        .clk(clk), .resetn(resetn), .trap(trap),
        .mem_valid(mem_valid), .mem_instr(mem_instr),
        .mem_ready(mem_ready), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata),
        .pcpi_wr(1'b0), .pcpi_rd(32'b0), .pcpi_wait(1'b0),
        .pcpi_ready(1'b0), .irq(32'b0)
    );

    ram main_ram (
        .clk(clk), .resetn(resetn), .mem_valid(mem_valid),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_ready(mem_ready), .mem_rdata(mem_rdata)
    );

    // One passive monitor for the CPU native memory bus.
    bus_trace trace_monitor (
        .clk(clk), .resetn(resetn), .cycle(cycles),
        .mem_valid(mem_valid), .mem_ready(mem_ready), .mem_instr(mem_instr),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata)
    );

    initial begin
        if (!$value$plusargs("lab=%d", lab) || (lab < 0 || lab > 5))
            $fatal(1, "Use +lab=0 through 5");
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
        end else begin
            expected_stores = 4;
            expected[0] = 32'h24;
            expected[1] = 32'h38;
            expected[2] = 32'hffffffff;
            expected[3] = 1;
        end
        repeat (10) @(negedge clk);
        resetn = 1;
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            if (lab == 0) $dumpfile("build/lab00.vcd");
            else if (lab == 1) $dumpfile("build/lab01.vcd");
            else if (lab == 2) $dumpfile("build/lab02.vcd");
            else if (lab == 3) $dumpfile("build/lab03.vcd");
            else if (lab == 4) $dumpfile("build/lab04.vcd");
            else $dumpfile("build/lab05.vcd");
            $dumpvars(0, riscv32_tb);
        end
    end

    // Lab-specific checks observe only completed bus transactions.
    always @(posedge clk) begin
        if (resetn && mem_valid && mem_ready) begin
            if (mem_instr) begin
                if (lab == 1 && fetches < 9 && mem_addr !== fetches * 4)
                    $fatal(1, "FAIL: expected PC %08x got %08x", fetches * 4, mem_addr);
                fetches <= fetches + 1;
            end
            if (|mem_wstrb) begin
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
                    mem_addr !== expected_addr ||
                    (lab == 4 && stores == 5
                      ? (mem_wstrb !== 4'b0010 || mem_wdata[15:8] !== 8'h01)
                      : lab == 4 && stores == 6
                      ? (mem_wstrb !== 4'b1100 || mem_wdata[31:16] !== 16'h7f01)
                      : (mem_wstrb !== 4'b1111 ||
                         mem_wdata !== expected[lab == 4 && stores == 7 ? 5 : stores])))
                    $fatal(1, "FAIL: store #%0d addr=%08x data=%08x strb=%b",
                           stores, mem_addr, mem_wdata, mem_wstrb);
                if (lab == 0)
                    $display("STORE addr=%08x value=%08x wstrb=%b",
                             mem_addr, mem_wdata, mem_wstrb);
                else
                    $display("STORE %0d addr=%08x data=%08x", stores, mem_addr, mem_wdata);
                if (stores == expected_stores - 1) completed <= 1;
                stores <= stores + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (resetn) begin
            cycles <= cycles + 1;
            if (trap) $fatal(1, "FAIL: unexpected CPU trap");
            if (completed) begin
                for (i=0; i<(lab == 4 ? 5 : expected_stores); i=i+1)
                    if (main_ram.memory[1024+i] !== expected[i])
                        $fatal(1, "FAIL: RAM[%0d] got %08x expected %08x",
                               i, main_ram.memory[1024+i], expected[i]);
                if (lab == 4 && (main_ram.memory[1029] !== 32'h7f010113 ||
                                 main_ram.memory[1030] !== 32'h7f010113))
                    $fatal(1, "FAIL: Lab04 byte lanes / reloaded word");
                if (lab == 1 && fetches < 9)
                    $fatal(1, "FAIL: too few instruction fetches (%0d)", fetches);
                if (lab == 0)
                    $display("PASS: Lab00 result=12 cycles=%0d", cycles);
                else if (lab == 1)
                    $display("PASS: Lab01 x0=0 x2=-3 x31=2 x1=5 cycles=%0d", cycles);
                else if (lab == 2)
                    $display("PASS: Lab02 R/I/S/B/U/J formats cycles=%0d", cycles);
                else if (lab == 3)
                    $display("PASS: Lab03 shifts and signedness cycles=%0d", cycles);
                else if (lab == 4)
                    $display("PASS: Lab04 load/store widths and strobes cycles=%0d", cycles);
                else
                    $display("PASS: Lab05 branches JAL JALR cycles=%0d", cycles);
                $finish;
            end
            if (cycles > 500) $fatal(1, "FAIL: timeout");
        end
    end
endmodule
