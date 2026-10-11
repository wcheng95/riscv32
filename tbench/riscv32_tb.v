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
    reg [31:0] expected [0:3];
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
        if (!$value$plusargs("lab=%d", lab) || (lab != 0 && lab != 1 && lab != 2))
            $fatal(1, "Use +lab=0, +lab=1 or +lab=2");
        if (lab == 0) begin
            expected_stores = 1;
            expected[0] = 12;
        end else if (lab == 1) begin
            expected_stores = 4;
            expected[0] = 0;
            expected[1] = 32'hfffffffd;
            expected[2] = 2;
            expected[3] = 5;
        end else begin
            expected_stores = 3;
            expected[0] = 12;
            expected[1] = 32'h28;
            expected[2] = 32'h10;
        end
        repeat (10) @(negedge clk);
        resetn = 1;
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            if (lab == 0) $dumpfile("build/lab00.vcd");
            else if (lab == 1) $dumpfile("build/lab01.vcd");
            else $dumpfile("build/lab02.vcd");
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
                expected_addr = 32'h1000 + stores * 4;
                if ((lab == 0 && stores >= 1) ||
                    (lab == 1 && stores >= 4) ||
                    (lab == 2 && stores >= 3) ||
                    mem_addr !== expected_addr ||
                    mem_wstrb !== 4'b1111 ||
                    mem_wdata !== expected[stores])
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
                for (i=0; i<expected_stores; i=i+1)
                    if (main_ram.memory[1024+i] !== expected[i])
                        $fatal(1, "FAIL: RAM[%0d] got %08x expected %08x",
                               i, main_ram.memory[1024+i], expected[i]);
                if (lab == 1 && fetches < 9)
                    $fatal(1, "FAIL: too few instruction fetches (%0d)", fetches);
                if (lab == 0)
                    $display("PASS: Lab00 result=12 cycles=%0d", cycles);
                else if (lab == 1)
                    $display("PASS: Lab01 x0=0 x2=-3 x31=2 x1=5 cycles=%0d", cycles);
                else
                    $display("PASS: Lab02 R/I/S/B/U/J formats cycles=%0d", cycles);
                $finish;
            end
            if (cycles > 500) $fatal(1, "FAIL: timeout");
        end
    end
endmodule
