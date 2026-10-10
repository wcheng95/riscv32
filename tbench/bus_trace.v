// Passive PicoRV32 native-memory handshake logger.
// Logs completed transactions only; never drives the bus.
`timescale 1ns/1ps
module bus_trace #(
    parameter FILE_NAME = "build/bus.trace"
) (
    input clk,
    input resetn,
    input [31:0] cycle,
    input mem_valid,
    input mem_ready,
    input mem_instr,
    input [31:0] mem_addr,
    input [31:0] mem_wdata,
    input [3:0] mem_wstrb,
    input [31:0] mem_rdata
);
    integer fd = 0;

    initial begin
        if ($test$plusargs("trace")) begin
            fd = $fopen(FILE_NAME, "w");
            if (fd == 0) begin
                $display("FAIL: unable to open trace file %s", FILE_NAME);
                $fatal(1);
            end
            $fdisplay(fd, "# PicoRV32 native memory transactions (completed handshakes)");
            $fdisplay(fd, "# CYCLE  TYPE    ADDRESS     DATA        STRB");
        end
    end

    always @(posedge clk) begin
        if (fd != 0 && resetn && mem_valid && mem_ready) begin
            if (|mem_wstrb)
                $fdisplay(fd, "%7d  WRITE   %08x    %08x    %04b",
                          cycle, mem_addr, mem_wdata, mem_wstrb);
            else if (mem_instr)
                $fdisplay(fd, "%7d  IFETCH  %08x    %08x    ----",
                          cycle, mem_addr, mem_rdata);
            else
                $fdisplay(fd, "%7d  READ    %08x    %08x    ----",
                          cycle, mem_addr, mem_rdata);
            $fflush(fd);
        end
    end

    final begin
        if (fd != 0) $fclose(fd);
    end
endmodule
