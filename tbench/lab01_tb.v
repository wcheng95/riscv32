`timescale 1ns/1ps
module lab01_tb;
    reg clk = 0;
    reg resetn = 0;
    always #5 clk = ~clk;

    wire trap, mem_valid, mem_instr;
    wire [31:0] mem_addr, mem_wdata;
    wire [3:0] mem_wstrb;
    reg mem_ready = 0;
    reg [31:0] mem_rdata = 0;
    reg [31:0] memory [0:2047];
    reg [31:0] expected [0:3];
    integer i, cycles = 0, stores = 0, fetches = 0;
    reg completed = 0;

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

    initial begin
        for (i = 0; i < 2048; i = i+1)
            memory[i] = 32'h00000013;
        $readmemh("build/lab01.hex", memory, 0, 9);
        for (i = 1024; i < 1028; i = i+1) memory[i] = 32'hdeadbeef;
        expected[0] = 32'h00000000;
        expected[1] = 32'hfffffffd;
        expected[2] = 32'h00000002;
        expected[3] = 32'h00000005;
        repeat (10) @(negedge clk);
        resetn = 1;
    end

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/lab01.vcd");
            $dumpvars(0, lab01_tb);
        end
    end

    // Same registered, single-outstanding-transaction RAM model as Lab00.
    always @(posedge clk) begin
        mem_ready <= 0;
        if (resetn && mem_valid && !mem_ready && mem_addr < 8192) begin
            mem_ready <= 1;
            mem_rdata <= memory[mem_addr >> 2];
            if (mem_wstrb[0]) memory[mem_addr >> 2][7:0] <= mem_wdata[7:0];
            if (mem_wstrb[1]) memory[mem_addr >> 2][15:8] <= mem_wdata[15:8];
            if (mem_wstrb[2]) memory[mem_addr >> 2][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) memory[mem_addr >> 2][31:24] <= mem_wdata[31:24];
        end
        if (resetn && mem_valid && mem_ready) begin
            if (mem_instr) begin
                // Only first nine straight-line instructions matter;
                // the tenth is the terminating park loop.
                if (fetches < 9 && mem_addr !== fetches * 4) begin
                    $display("FAIL: expected sequential PC %08x, got %08x",
                             fetches * 4, mem_addr);
                    $fatal(1);
                end
                fetches <= fetches + 1;
            end
            if (|mem_wstrb) begin
                if (stores >= 4 || mem_addr !== (32'h1000 + stores * 4) ||
                    mem_wstrb !== 4'b1111 || mem_wdata !== expected[stores]) begin
                    $display("FAIL: store #%0d addr=%08x data=%08x strb=%b",
                             stores, mem_addr, mem_wdata, mem_wstrb);
                    $fatal(1);
                end
                $display("STORE %0d addr=%08x data=%08x", stores, mem_addr, mem_wdata);
                stores <= stores + 1;
                if (stores == 3) completed <= 1;
            end
        end
    end

    always @(posedge clk) begin
        if (resetn) begin
            cycles <= cycles + 1;
            if (trap) begin
                $display("FAIL: unexpected CPU trap");
                $fatal(1);
            end
            if (completed) begin
                for (i = 0; i < 4; i = i+1)
                    if (memory[1024+i] !== expected[i]) begin
                        $display("FAIL: memory[%0d]=%08x expected %08x",
                                 i, memory[1024+i], expected[i]);
                        $fatal(1);
                    end
                if (fetches < 9) begin
                    $display("FAIL: too few instruction fetches (%0d)", fetches);
                    $fatal(1);
                end
                $display("PASS: Lab01 x0=0 x2=-3 x31=2 x1=5 cycles=%0d", cycles);
                $finish;
            end
            if (cycles > 500) begin
                $display("FAIL: timeout");
                $fatal(1);
            end
        end
    end
endmodule
