// Cycle-visible equivalence check: upstream fixed RV32I PicoRV32 vs Phase-A clean core.
`timescale 1ns/1ps

module rv32i_equiv_tb;
    reg clk = 0;
    reg resetn = 0;
    always #5 clk = ~clk;

    integer lab = -1;
    integer cycles = 0;
    integer stores = 0;
    integer expected_stores;
    integer words = 0;

    wire trap_ref, trap_clean;

    wire ref_valid, ref_instr, ref_ready;
    wire [31:0] ref_addr, ref_wdata, ref_rdata;
    wire [3:0] ref_wstrb;

    wire clean_valid, clean_instr, clean_ready;
    wire [31:0] clean_addr, clean_wdata, clean_rdata;
    wire [3:0] clean_wstrb;

    picorv32 #(
        .ENABLE_COUNTERS(0),
        .ENABLE_COUNTERS64(0),
        .ENABLE_REGS_16_31(1),
        .ENABLE_REGS_DUALPORT(1),
        .LATCHED_MEM_RDATA(0),
        .TWO_STAGE_SHIFT(1),
        .BARREL_SHIFTER(0),
        .TWO_CYCLE_COMPARE(0),
        .TWO_CYCLE_ALU(0),
        .COMPRESSED_ISA(0),
        .CATCH_MISALIGN(1),
        .CATCH_ILLINSN(1),
        .ENABLE_PCPI(0),
        .ENABLE_MUL(0),
        .ENABLE_FAST_MUL(0),
        .ENABLE_DIV(0),
        .ENABLE_IRQ(0),
        .ENABLE_IRQ_TIMER(0),
        .ENABLE_TRACE(0),
        .REGS_INIT_ZERO(0),
        .PROGADDR_RESET(32'h0),
        .STACKADDR(32'hffff_ffff)
    ) ref_cpu (
        .clk(clk),
        .resetn(resetn),
        .trap(trap_ref),
        .mem_valid(ref_valid),
        .mem_instr(ref_instr),
        .mem_ready(ref_ready),
        .mem_addr(ref_addr),
        .mem_wdata(ref_wdata),
        .mem_wstrb(ref_wstrb),
        .mem_rdata(ref_rdata),
        .pcpi_wr(1'b0),
        .pcpi_rd(32'b0),
        .pcpi_wait(1'b0),
        .pcpi_ready(1'b0),
        .irq(32'b0)
    );

    picorv32_rv32i_clean clean_cpu (
        .clk(clk),
        .resetn(resetn),
        .trap(trap_clean),
        .mem_valid(clean_valid),
        .mem_instr(clean_instr),
        .mem_ready(clean_ready),
        .mem_addr(clean_addr),
        .mem_wdata(clean_wdata),
        .mem_wstrb(clean_wstrb),
        .mem_rdata(clean_rdata)
    );

    ram ref_ram (
        .clk(clk), .resetn(resetn),
        .mem_valid(ref_valid), .mem_addr(ref_addr),
        .mem_wdata(ref_wdata), .mem_wstrb(ref_wstrb),
        .mem_ready(ref_ready), .mem_rdata(ref_rdata)
    );

    ram clean_ram (
        .clk(clk), .resetn(resetn),
        .mem_valid(clean_valid), .mem_addr(clean_addr),
        .mem_wdata(clean_wdata), .mem_wstrb(clean_wstrb),
        .mem_ready(clean_ready), .mem_rdata(clean_rdata)
    );

    initial begin
        if (!$value$plusargs("lab=%d", lab) || lab < 0 || lab > 6)
            $fatal(1, "Use +lab=0 through 6");
        if (!$value$plusargs("words=%d", words))
            $fatal(1, "Use +words=<program words>");

        case (lab)
            0: expected_stores = 1;
            1: expected_stores = 4;
            2: expected_stores = 3;
            3: expected_stores = 4;
            4: expected_stores = 8;
            5: expected_stores = 4;
            6: expected_stores = 2;
        endcase

        repeat (10) @(negedge clk);
        resetn = 1;
    end

    always @(posedge clk) begin
        if (resetn) begin
            cycles <= cycles + 1;

            if (trap_ref !== trap_clean)
                $fatal(1, "trap mismatch cycle=%0d ref=%b clean=%b",
                       cycles, trap_ref, trap_clean);

            if (ref_valid !== clean_valid)
                $fatal(1, "mem_valid mismatch cycle=%0d ref=%b clean=%b",
                       cycles, ref_valid, clean_valid);

            if (ref_valid && clean_valid) begin
                if (ref_instr !== clean_instr ||
                    ref_addr !== clean_addr ||
                    ref_wstrb !== clean_wstrb)
                    $fatal(1,
                        "bus mismatch cycle=%0d ref(instr=%b addr=%08x strb=%b) clean(instr=%b addr=%08x strb=%b)",
                        cycles, ref_instr, ref_addr, ref_wstrb,
                        clean_instr, clean_addr, clean_wstrb);

                if (|ref_wstrb && ref_wdata !== clean_wdata)
                    $fatal(1, "write-data mismatch cycle=%0d ref=%08x clean=%08x",
                           cycles, ref_wdata, clean_wdata);
            end

            if (ref_ready !== clean_ready)
                $fatal(1, "mem_ready mismatch cycle=%0d ref=%b clean=%b",
                       cycles, ref_ready, clean_ready);

            if (ref_valid && ref_ready && |ref_wstrb) begin
                stores <= stores + 1;
                if (stores + 1 == expected_stores) begin
                    $display("PASS: Phase-A equivalence lab%02d cycles=%0d", lab, cycles);
                    $finish;
                end
            end

            if (trap_ref || trap_clean)
                $fatal(1, "unexpected trap in equivalence lab%02d", lab);

            if (cycles > 1200)
                $fatal(1, "equivalence timeout lab%02d", lab);
        end
    end
endmodule
