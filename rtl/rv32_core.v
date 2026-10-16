// Phase B: independent small RV32I core.
//
// This is intentionally simpler than PicoRV32:
//   - RV32I only
//   - one instruction in flight
//   - no prefetch/look-ahead interface
//   - no counters, C, M, PCPI, IRQ, trace, or formal plumbing
//   - one native 32-bit valid/ready memory bus
//
// It is the starting point for the later Zicsr + M-mode FreeRTOS MCU work.

`timescale 1ns/1ps

module rv32_core #(
    parameter [31:0] PROGADDR_RESET = 32'h0000_0000,
    parameter [31:0] STACKADDR      = 32'hffff_ffff,
    parameter [0:0]  CATCH_MISALIGN = 1,
    parameter [0:0]  CATCH_ILLINSN  = 1
) (
    input             clk,
    input             resetn,
    output reg        trap,

    output reg        mem_valid,
    output reg        mem_instr,
    input             mem_ready,
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    output reg [3:0]  mem_wstrb,
    input      [31:0] mem_rdata
);

    localparam [1:0] ST_FETCH = 2'd0;
    localparam [1:0] ST_EXEC  = 2'd1;
    localparam [1:0] ST_MEM   = 2'd2;
    localparam [1:0] ST_TRAP  = 2'd3;

    reg [1:0] state;

    reg [31:0] pc;
    reg [31:0] insn;
    reg [31:0] regs [0:31];

    // Saved metadata for an outstanding data-memory transaction.
    reg        mem_is_load;
    reg [4:0]  mem_rd;
    reg [1:0]  mem_size;       // 0=byte, 1=halfword, 2=word
    reg        mem_unsigned;
    reg [1:0]  mem_addr_low;

    wire [6:0] opcode = insn[6:0];
    wire [2:0] funct3 = insn[14:12];
    wire [6:0] funct7 = insn[31:25];
    wire [4:0] rd     = insn[11:7];
    wire [4:0] rs1    = insn[19:15];
    wire [4:0] rs2    = insn[24:20];

    wire [31:0] rs1_value = rs1 == 0 ? 32'b0 : regs[rs1];
    wire [31:0] rs2_value = rs2 == 0 ? 32'b0 : regs[rs2];

    wire [31:0] imm_i = {{20{insn[31]}}, insn[31:20]};
    wire [31:0] imm_s = {{20{insn[31]}}, insn[31:25], insn[11:7]};
    wire [31:0] imm_b = {{19{insn[31]}}, insn[31], insn[7],
                         insn[30:25], insn[11:8], 1'b0};
    wire [31:0] imm_u = {insn[31:12], 12'b0};
    wire [31:0] imm_j = {{11{insn[31]}}, insn[31], insn[19:12],
                         insn[20], insn[30:21], 1'b0};

    reg [31:0] eff_addr;
    reg [31:0] target;
    reg        take_branch;
    reg        valid_branch;
    reg        valid_load;
    reg        valid_store;
    reg        valid_op_imm;
    reg        valid_op;
    reg [31:0] result;

    // Combinational helpers used by the execute state.
    always @* begin
        eff_addr = rs1_value + imm_i;
        target = 32'b0;
        take_branch = 0;
        valid_branch = 1;
        valid_load = 1;
        valid_store = 1;
        valid_op_imm = 1;
        valid_op = 1;
        result = 32'b0;

        case (funct3)
            3'b000: take_branch = rs1_value == rs2_value;                  // BEQ
            3'b001: take_branch = rs1_value != rs2_value;                  // BNE
            3'b100: take_branch = $signed(rs1_value) < $signed(rs2_value); // BLT
            3'b101: take_branch = $signed(rs1_value) >= $signed(rs2_value);// BGE
            3'b110: take_branch = rs1_value < rs2_value;                    // BLTU
            3'b111: take_branch = rs1_value >= rs2_value;                   // BGEU
            default: valid_branch = 0;
        endcase

        case (funct3)
            3'b000, 3'b100: ; // LB/LBU
            3'b001, 3'b101: ; // LH/LHU
            3'b010: ;         // LW
            default: valid_load = 0;
        endcase

        case (funct3)
            3'b000, 3'b001, 3'b010: ;
            default: valid_store = 0;
        endcase

        case (funct3)
            3'b000: result = rs1_value + imm_i; // ADDI
            3'b010: result = $signed(rs1_value) < $signed(imm_i); // SLTI
            3'b011: result = rs1_value < imm_i; // SLTIU
            3'b100: result = rs1_value ^ imm_i; // XORI
            3'b110: result = rs1_value | imm_i; // ORI
            3'b111: result = rs1_value & imm_i; // ANDI
            3'b001: begin
                if (funct7 == 7'b0000000)
                    result = rs1_value << insn[24:20];
                else
                    valid_op_imm = 0;
            end
            3'b101: begin
                if (funct7 == 7'b0000000)
                    result = rs1_value >> insn[24:20];
                else if (funct7 == 7'b0100000)
                    result = $signed(rs1_value) >>> insn[24:20];
                else
                    valid_op_imm = 0;
            end
            default: valid_op_imm = 0;
        endcase

        case (funct3)
            3'b000: begin
                if (funct7 == 7'b0000000)
                    result = rs1_value + rs2_value;
                else if (funct7 == 7'b0100000)
                    result = rs1_value - rs2_value;
                else
                    valid_op = 0;
            end
            3'b001: begin
                if (funct7 == 7'b0000000)
                    result = rs1_value << rs2_value[4:0];
                else
                    valid_op = 0;
            end
            3'b010: begin
                if (funct7 == 7'b0000000)
                    result = $signed(rs1_value) < $signed(rs2_value);
                else
                    valid_op = 0;
            end
            3'b011: begin
                if (funct7 == 7'b0000000)
                    result = rs1_value < rs2_value;
                else
                    valid_op = 0;
            end
            3'b100: begin
                if (funct7 == 7'b0000000)
                    result = rs1_value ^ rs2_value;
                else
                    valid_op = 0;
            end
            3'b101: begin
                if (funct7 == 7'b0000000)
                    result = rs1_value >> rs2_value[4:0];
                else if (funct7 == 7'b0100000)
                    result = $signed(rs1_value) >>> rs2_value[4:0];
                else
                    valid_op = 0;
            end
            3'b110: begin
                if (funct7 == 7'b0000000)
                    result = rs1_value | rs2_value;
                else
                    valid_op = 0;
            end
            3'b111: begin
                if (funct7 == 7'b0000000)
                    result = rs1_value & rs2_value;
                else
                    valid_op = 0;
            end
            default: valid_op = 0;
        endcase
    end

    reg [31:0] load_value;

    always @* begin
        case (mem_size)
            0: begin
                case (mem_addr_low)
                    2'b00: load_value = mem_unsigned
                                          ? {24'b0, mem_rdata[7:0]}
                                          : {{24{mem_rdata[7]}}, mem_rdata[7:0]};
                    2'b01: load_value = mem_unsigned
                                          ? {24'b0, mem_rdata[15:8]}
                                          : {{24{mem_rdata[15]}}, mem_rdata[15:8]};
                    2'b10: load_value = mem_unsigned
                                          ? {24'b0, mem_rdata[23:16]}
                                          : {{24{mem_rdata[23]}}, mem_rdata[23:16]};
                    2'b11: load_value = mem_unsigned
                                          ? {24'b0, mem_rdata[31:24]}
                                          : {{24{mem_rdata[31]}}, mem_rdata[31:24]};
                endcase
            end
            1: begin
                if (mem_addr_low[1] == 0)
                    load_value = mem_unsigned
                               ? {16'b0, mem_rdata[15:0]}
                               : {{16{mem_rdata[15]}}, mem_rdata[15:0]};
                else
                    load_value = mem_unsigned
                               ? {16'b0, mem_rdata[31:16]}
                               : {{16{mem_rdata[31]}}, mem_rdata[31:16]};
            end
            default:
                load_value = mem_rdata;
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) begin
            state <= ST_FETCH;
            pc <= PROGADDR_RESET;
            trap <= 0;
            mem_valid <= 0;
            mem_instr <= 0;
            mem_addr <= 0;
            mem_wdata <= 0;
            mem_wstrb <= 0;
            mem_is_load <= 0;
            mem_rd <= 0;
            mem_size <= 0;
            mem_unsigned <= 0;
            mem_addr_low <= 0;

            if (STACKADDR != 32'hffff_ffff)
                regs[2] <= STACKADDR;
        end else begin
            case (state)
                ST_FETCH: begin
                    if (CATCH_MISALIGN && |pc[1:0]) begin
                        trap <= 1;
                        mem_valid <= 0;
                        state <= ST_TRAP;
                    end else if (!mem_valid) begin
                        mem_valid <= 1;
                        mem_instr <= 1;
                        mem_addr <= pc;
                        mem_wstrb <= 0;
                    end else if (mem_ready) begin
                        insn <= mem_rdata;
                        mem_valid <= 0;
                        mem_instr <= 0;
                        state <= ST_EXEC;
                    end
                end

                ST_EXEC: begin
                    case (opcode)
                        7'b0110111: begin // LUI
                            if (rd != 0) regs[rd] <= imm_u;
                            pc <= pc + 4;
                            state <= ST_FETCH;
                        end

                        7'b0010111: begin // AUIPC
                            if (rd != 0) regs[rd] <= pc + imm_u;
                            pc <= pc + 4;
                            state <= ST_FETCH;
                        end

                        7'b1101111: begin // JAL
                            target = pc + imm_j;
                            if (CATCH_MISALIGN && |target[1:0]) begin
                                trap <= 1;
                                state <= ST_TRAP;
                            end else begin
                                if (rd != 0) regs[rd] <= pc + 4;
                                pc <= target;
                                state <= ST_FETCH;
                            end
                        end

                        7'b1100111: begin // JALR
                            if (funct3 != 3'b000) begin
                                if (CATCH_ILLINSN) begin
                                    trap <= 1;
                                    state <= ST_TRAP;
                                end
                            end else begin
                                target = (rs1_value + imm_i) & 32'hffff_fffe;
                                if (CATCH_MISALIGN && |target[1:0]) begin
                                    trap <= 1;
                                    state <= ST_TRAP;
                                end else begin
                                    if (rd != 0) regs[rd] <= pc + 4;
                                    pc <= target;
                                    state <= ST_FETCH;
                                end
                            end
                        end

                        7'b1100011: begin // branches
                            if (!valid_branch) begin
                                if (CATCH_ILLINSN) begin
                                    trap <= 1;
                                    state <= ST_TRAP;
                                end
                            end else if (take_branch) begin
                                target = pc + imm_b;
                                if (CATCH_MISALIGN && |target[1:0]) begin
                                    trap <= 1;
                                    state <= ST_TRAP;
                                end else begin
                                    pc <= target;
                                    state <= ST_FETCH;
                                end
                            end else begin
                                pc <= pc + 4;
                                state <= ST_FETCH;
                            end
                        end

                        7'b0000011: begin // loads
                            eff_addr = rs1_value + imm_i;
                            if (!valid_load) begin
                                if (CATCH_ILLINSN) begin
                                    trap <= 1;
                                    state <= ST_TRAP;
                                end
                            end else if (CATCH_MISALIGN &&
                                ((funct3 == 3'b010 && |eff_addr[1:0]) ||
                                 ((funct3 == 3'b001 || funct3 == 3'b101) && eff_addr[0]))) begin
                                trap <= 1;
                                state <= ST_TRAP;
                            end else begin
                                mem_valid <= 1;
                                mem_instr <= 0;
                                mem_addr <= {eff_addr[31:2], 2'b00};
                                mem_wstrb <= 0;
                                mem_is_load <= 1;
                                mem_rd <= rd;
                                mem_addr_low <= eff_addr[1:0];

                                case (funct3)
                                    3'b000: begin mem_size <= 0; mem_unsigned <= 0; end
                                    3'b100: begin mem_size <= 0; mem_unsigned <= 1; end
                                    3'b001: begin mem_size <= 1; mem_unsigned <= 0; end
                                    3'b101: begin mem_size <= 1; mem_unsigned <= 1; end
                                    default: begin mem_size <= 2; mem_unsigned <= 0; end
                                endcase

                                state <= ST_MEM;
                            end
                        end

                        7'b0100011: begin // stores
                            eff_addr = rs1_value + imm_s;
                            if (!valid_store) begin
                                if (CATCH_ILLINSN) begin
                                    trap <= 1;
                                    state <= ST_TRAP;
                                end
                            end else if (CATCH_MISALIGN &&
                                ((funct3 == 3'b010 && |eff_addr[1:0]) ||
                                 (funct3 == 3'b001 && eff_addr[0]))) begin
                                trap <= 1;
                                state <= ST_TRAP;
                            end else begin
                                mem_valid <= 1;
                                mem_instr <= 0;
                                mem_addr <= {eff_addr[31:2], 2'b00};
                                mem_is_load <= 0;
                                mem_addr_low <= eff_addr[1:0];

                                case (funct3)
                                    3'b000: begin
                                        mem_wdata <= {4{rs2_value[7:0]}};
                                        mem_wstrb <= 4'b0001 << eff_addr[1:0];
                                    end
                                    3'b001: begin
                                        mem_wdata <= {2{rs2_value[15:0]}};
                                        mem_wstrb <= eff_addr[1] ? 4'b1100 : 4'b0011;
                                    end
                                    default: begin
                                        mem_wdata <= rs2_value;
                                        mem_wstrb <= 4'b1111;
                                    end
                                endcase

                                state <= ST_MEM;
                            end
                        end

                        7'b0010011: begin // OP-IMM
                            if (!valid_op_imm) begin
                                if (CATCH_ILLINSN) begin
                                    trap <= 1;
                                    state <= ST_TRAP;
                                end
                            end else begin
                                if (rd != 0) regs[rd] <= result;
                                pc <= pc + 4;
                                state <= ST_FETCH;
                            end
                        end

                        7'b0110011: begin // OP
                            if (!valid_op) begin
                                if (CATCH_ILLINSN) begin
                                    trap <= 1;
                                    state <= ST_TRAP;
                                end
                            end else begin
                                if (rd != 0) regs[rd] <= result;
                                pc <= pc + 4;
                                state <= ST_FETCH;
                            end
                        end

                        7'b0001111: begin // FENCE only; FENCE.I is not base RV32I here
                            if (funct3 == 3'b000) begin
                                pc <= pc + 4;
                                state <= ST_FETCH;
                            end else if (CATCH_ILLINSN) begin
                                trap <= 1;
                                state <= ST_TRAP;
                            end
                        end

                        7'b1110011: begin // ECALL/EBREAK and unsupported SYSTEM/CSR
                            trap <= 1;
                            state <= ST_TRAP;
                        end

                        default: begin
                            if (CATCH_ILLINSN) begin
                                trap <= 1;
                                state <= ST_TRAP;
                            end else begin
                                pc <= pc + 4;
                                state <= ST_FETCH;
                            end
                        end
                    endcase
                end

                ST_MEM: begin
                    if (mem_ready) begin
                        if (mem_is_load && mem_rd != 0)
                            regs[mem_rd] <= load_value;

                        mem_valid <= 0;
                        mem_wstrb <= 0;
                        pc <= pc + 4;
                        state <= ST_FETCH;
                    end
                end

                ST_TRAP: begin
                    trap <= 1;
                    mem_valid <= 0;
                end
            endcase
        end
    end

endmodule
