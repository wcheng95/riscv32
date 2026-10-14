// Standalone illustrative PCPI unit: custom-0 instruction -> rs1 + rs2 + 1.
// Three cycles of internal waiting; independent of lab selection.
`timescale 1ns/1ps
module pcpi_demo (
    input clk, input resetn,
    input pcpi_valid,
    input [31:0] pcpi_insn, pcpi_rs1, pcpi_rs2,
    output wire pcpi_wait, pcpi_ready, pcpi_wr,
    output wire [31:0] pcpi_rd
);
    // Matches the entire instruction for this tiny experiment.
    wire match_insn = (pcpi_insn == 32'h0020818b);
    reg [2:0] count = 0;
    reg ready = 0;
    reg [31:0] result = 0;
    wire active = pcpi_valid && match_insn;

    assign pcpi_wait = active && !ready;
    assign pcpi_ready = active && ready;
    assign pcpi_wr = pcpi_ready;
    assign pcpi_rd = result;

    always @(posedge clk) begin
        if (!resetn || !pcpi_valid) begin
            count <= 0;
            ready <= 0;
        end else if (active && !ready) begin
            if (count == 3) begin
                result <= pcpi_rs1 + pcpi_rs2 + 1;
                ready <= 1;
            end else
                count <= count + 1;
        end
    end
endmodule
