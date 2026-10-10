// Lab00: minimal, independent PicoRV32 native-bus testbench
`timescale 1ns/1ps
module riscv32_tb;
    reg clk = 0;
    reg resetn = 0;
    always #5 clk = ~clk;

    wire trap, mem_valid, mem_instr;
    reg mem_ready = 0;
    wire [31:0] mem_addr, mem_wdata;
    wire [3:0] mem_wstrb;
    reg [31:0] mem_rdata = 0;
    reg [31:0] memory [0:2047]; // 8 KiB; program at 0, data at 0x1000
    integer i;
    integer cycles = 0;
    reg passed = 0;

    picorv32 #(
        .COMPRESSED_ISA(0),
        .ENABLE_MUL(0),
        .ENABLE_DIV(0),
        .ENABLE_PCPI(0),
        .ENABLE_IRQ(0),
        .PROGADDR_RESET(32'h00000000)
    ) cpu (
        .clk(clk), .resetn(resetn), .trap(trap),
        .mem_valid(mem_valid), .mem_instr(mem_instr),
        .mem_ready(mem_ready), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata),
        .pcpi_wr(1'b0), .pcpi_rd(32'b0), .pcpi_wait(1'b0),
        .pcpi_ready(1'b0), .irq(32'b0)
    );

    initial begin
        for (i = 0; i < 2048; i = i + 1) memory[i] = 32'h00000013; // NOP
        // Load the assembled Lab00 instruction image, not hand-written opcodes.
        $readmemh("build/lab00.hex", memory, 0, 5);
        memory[1024] = 32'h00000000;
        repeat (10) @(negedge clk);
        resetn = 1;
    end

    // Optional passive, per-lab trace; no effect on memory timing.
    bus_trace #(.FILE_NAME("build/lab00.trace")) trace_monitor (
        .clk(clk), .resetn(resetn), .cycle(cycles),
        .mem_valid(mem_valid), .mem_ready(mem_ready), .mem_instr(mem_instr),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata)
    );

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/lab00.vcd");
            $dumpvars(0, riscv32_tb);
        end
    end

    // One-cycle registered memory response, with byte enables.
    always @(posedge clk) begin
        mem_ready <= 0;
        if (resetn && mem_valid && !mem_ready && mem_addr < 8192) begin
            mem_ready <= 1;
            mem_rdata <= memory[mem_addr >> 2];
            if (mem_wstrb[0]) memory[mem_addr >> 2][7:0]   <= mem_wdata[7:0];
            if (mem_wstrb[1]) memory[mem_addr >> 2][15:8]  <= mem_wdata[15:8];
            if (mem_wstrb[2]) memory[mem_addr >> 2][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) memory[mem_addr >> 2][31:24] <= mem_wdata[31:24];
        end
        if (resetn && mem_valid && mem_ready && |mem_wstrb) begin
            $display("STORE addr=%08x value=%08x wstrb=%b", mem_addr, mem_wdata, mem_wstrb);
            if (mem_addr !== 32'h1000 || mem_wstrb !== 4'b1111 ||
                mem_wdata !== 32'd12) begin
                $display("FAIL: unexpected store");
                $fatal(1);
            end
            passed <= 1;
        end
    end

    always @(posedge clk) begin
        if (resetn) begin
            cycles <= cycles + 1;
            if (trap) begin
                $display("FAIL: CPU trap");
                $fatal(1);
            end
            if (passed) begin
                if (memory[1024] !== 32'd12) begin
                    $display("FAIL: RAM did not contain 12");
                    $fatal(1);
                end
                $display("PASS: Lab00 result=12 cycles=%0d", cycles);
                $finish;
            end
            if (cycles > 500) begin
                $display("FAIL: timeout");
                $fatal(1);
            end
        end
    end
endmodule
