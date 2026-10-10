// Lab RAM. One registered response, byte-write enables, same timing as Lab00/01.
`timescale 1ns/1ps
module ram (
    input clk, input resetn,
    input mem_valid, input [31:0] mem_addr,
    input [31:0] mem_wdata, input [3:0] mem_wstrb,
    output reg mem_ready = 0,
    output reg [31:0] mem_rdata = 0
);
    reg [31:0] memory [0:2047];
    integer i, words;
    reg [1023:0] hexfile;
    initial begin
        for (i = 0; i < 2048; i=i+1) memory[i] = 32'h00000013;
        if (!$value$plusargs("hex=%s", hexfile) ||
            !$value$plusargs("words=%d", words)) begin
            $display("FAIL: supply +hex=<file> +words=<count>");
            $fatal(1);
        end
        if (words < 1 || words > 1024) $fatal(1, "invalid program size");
        $readmemh(hexfile, memory, 0, words-1);
        // Lab result area, intentionally distinct from executable code.
        for (i=1024; i<1028; i=i+1) memory[i] = 32'hdeadbeef;
    end
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
    end
endmodule
