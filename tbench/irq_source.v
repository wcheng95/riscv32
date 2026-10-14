// One-shot external IRQ source; independent of lab selection and CPU internals.
`timescale 1ns/1ps
module irq_source (
    input clk, input resetn, input enable,
    output reg [31:0] irq = 0
);
    integer ticks = 0;
    always @(posedge clk) begin
        if (!resetn) begin
            ticks <= 0;
            irq <= 0;
        end else if (enable) begin
            ticks <= ticks + 1;
            irq <= (ticks == 40) ? 32'h00000008 : 32'b0;
        end else begin
            irq <= 0;
        end
    end
endmodule
