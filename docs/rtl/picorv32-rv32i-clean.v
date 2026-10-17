// Phase A: mechanically cleaned fixed-RV32I PicoRV32 core.
// Derived from the PicoRV32 control/datapath structure with disabled
// configuration families removed. This is a study/reference core, not upstream.
//
// Fixed choices:
//   RV32I, 32 registers, dual-port register file
//   no C, M, PCPI, IRQ, counters, trace, RVFI/formal
//   iterative shifter, TWO_STAGE_SHIFT behavior
//   single-cycle combinational ALU/compare
//
// The native memory interface intentionally preserves PicoRV32's prefetch and
// valid/ready timing so this core can be checked cycle-for-cycle against the
// pinned upstream core under the same fixed configuration.

`timescale 1ns/1ps

module picorv32_rv32i_clean #(
    parameter [31:0] PROGADDR_RESET = 32'h0000_0000,
    parameter [31:0] STACKADDR      = 32'hffff_ffff,
    parameter [0:0]  CATCH_MISALIGN = 1,
    parameter [0:0]  CATCH_ILLINSN  = 1,
    parameter [0:0]  TWO_STAGE_SHIFT = 1
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

    // ------------------------------------------------------------------------
    // Core datapath state
    // ------------------------------------------------------------------------

    reg [31:0] reg_pc, reg_next_pc, reg_op1, reg_op2, reg_out;
    reg [4:0]  reg_sh;
    reg [31:0] next_insn_opcode;
    reg [31:0] cpuregs [0:31];
    wire [31:0] next_pc;
    // ------------------------------------------------------------------------
    // Memory interface
    // ------------------------------------------------------------------------

    reg [1:0]  mem_state;
    reg [1:0]  mem_wordsize;
    reg [31:0] mem_rdata_word;
    reg [31:0] mem_rdata_q;
    reg        mem_do_prefetch;
    reg        mem_do_rinst;
    reg        mem_do_rdata;
    reg        mem_do_wdata;

    wire mem_xfer = mem_valid && mem_ready;
    wire mem_done = resetn &&
        ((mem_xfer && |mem_state && (mem_do_rinst || mem_do_rdata || mem_do_wdata)) ||
         (&mem_state && mem_do_rinst));

    wire        mem_la_read  = resetn && !mem_state &&
                               (mem_do_rinst || mem_do_prefetch || mem_do_rdata);
    wire        mem_la_write = resetn && !mem_state && mem_do_wdata;
    wire [31:0] mem_la_addr  = (mem_do_prefetch || mem_do_rinst)
                             ? {next_pc[31:2], 2'b00}
                             : {reg_op1[31:2], 2'b00};
    reg [31:0]  mem_la_wdata;
    reg [3:0]   mem_la_wstrb;

    wire [31:0] mem_rdata_latched = mem_xfer ? mem_rdata : mem_rdata_q;

    always @* begin
        case (mem_wordsize)
            0: begin
                mem_la_wdata = reg_op2;
                mem_la_wstrb = 4'b1111;
                mem_rdata_word = mem_rdata;
            end
            1: begin
                mem_la_wdata = {2{reg_op2[15:0]}};
                mem_la_wstrb = reg_op1[1] ? 4'b1100 : 4'b0011;
                case (reg_op1[1])
                    1'b0: mem_rdata_word = {16'b0, mem_rdata[15:0]};
                    1'b1: mem_rdata_word = {16'b0, mem_rdata[31:16]};
                endcase
            end
            2: begin
                mem_la_wdata = {4{reg_op2[7:0]}};
                mem_la_wstrb = 4'b0001 << reg_op1[1:0];
                case (reg_op1[1:0])
                    2'b00: mem_rdata_word = {24'b0, mem_rdata[7:0]};
                    2'b01: mem_rdata_word = {24'b0, mem_rdata[15:8]};
                    2'b10: mem_rdata_word = {24'b0, mem_rdata[23:16]};
                    2'b11: mem_rdata_word = {24'b0, mem_rdata[31:24]};
                endcase
            end
            default: begin
                mem_la_wdata = 32'bx;
                mem_la_wstrb = 4'b0000;
                mem_rdata_word = 32'bx;
            end
        endcase
    end

    always @(posedge clk) begin
        if (mem_xfer) begin
            mem_rdata_q <= mem_rdata;
            next_insn_opcode <= mem_rdata;
        end

        if (!resetn || trap) begin
            if (!resetn)
                mem_state <= 0;
            if (!resetn || mem_ready)
                mem_valid <= 0;
        end else begin
            if (mem_la_read || mem_la_write) begin
                mem_addr <= mem_la_addr;
                mem_wstrb <= mem_la_wstrb & {4{mem_la_write}};
            end
            if (mem_la_write)
                mem_wdata <= mem_la_wdata;

            case (mem_state)
                0: begin
                    if (mem_do_prefetch || mem_do_rinst || mem_do_rdata) begin
                        mem_valid <= 1;
                        mem_instr <= mem_do_prefetch || mem_do_rinst;
                        mem_wstrb <= 0;
                        mem_state <= 1;
                    end
                    if (mem_do_wdata) begin
                        mem_valid <= 1;
                        mem_instr <= 0;
                        mem_state <= 2;
                    end
                end
                1: begin
                    if (mem_xfer) begin
                        mem_valid <= 0;
                        mem_state <= mem_do_rinst || mem_do_rdata ? 0 : 3;
                    end
                end
                2: begin
                    if (mem_xfer) begin
                        mem_valid <= 0;
                        mem_state <= 0;
                    end
                end
                3: begin
                    if (mem_do_rinst)
                        mem_state <= 0;
                end
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Instruction decoder
    // ------------------------------------------------------------------------

    reg instr_lui, instr_auipc, instr_jal, instr_jalr;
    reg instr_beq, instr_bne, instr_blt, instr_bge, instr_bltu, instr_bgeu;
    reg instr_lb, instr_lh, instr_lw, instr_lbu, instr_lhu;
    reg instr_sb, instr_sh, instr_sw;
    reg instr_addi, instr_slti, instr_sltiu, instr_xori, instr_ori, instr_andi;
    reg instr_slli, instr_srli, instr_srai;
    reg instr_add, instr_sub, instr_sll, instr_slt, instr_sltu;
    reg instr_xor, instr_srl, instr_sra, instr_or, instr_and;
    reg instr_ecall_ebreak, instr_fence;

    reg [4:0]  decoded_rd, decoded_rs1, decoded_rs2;
    reg [31:0] decoded_imm, decoded_imm_j;
    reg        decoder_trigger;
    reg        decoder_pseudo_trigger;

    reg is_lui_auipc_jal;
    reg is_lb_lh_lw_lbu_lhu;
    reg is_slli_srli_srai;
    reg is_jalr_addi_slti_sltiu_xori_ori_andi;
    reg is_sb_sh_sw;
    reg is_sll_srl_sra;
    reg is_lui_auipc_jal_jalr_addi_add_sub;
    reg is_slti_blt_slt;
    reg is_sltiu_bltu_sltu;
    reg is_beq_bne_blt_bge_bltu_bgeu;
    reg is_lbu_lhu_lw;
    reg is_alu_reg_imm;
    reg is_alu_reg_reg;
    reg is_compare;

    wire instr_trap = CATCH_ILLINSN && !{
        instr_lui, instr_auipc, instr_jal, instr_jalr,
        instr_beq, instr_bne, instr_blt, instr_bge, instr_bltu, instr_bgeu,
        instr_lb, instr_lh, instr_lw, instr_lbu, instr_lhu,
        instr_sb, instr_sh, instr_sw,
        instr_addi, instr_slti, instr_sltiu, instr_xori, instr_ori, instr_andi,
        instr_slli, instr_srli, instr_srai,
        instr_add, instr_sub, instr_sll, instr_slt, instr_sltu,
        instr_xor, instr_srl, instr_sra, instr_or, instr_and,
        instr_fence
    };

    always @(posedge clk) begin
        is_lui_auipc_jal <= |{instr_lui, instr_auipc, instr_jal};
        is_lui_auipc_jal_jalr_addi_add_sub <=
            |{instr_lui, instr_auipc, instr_jal, instr_jalr,
              instr_addi, instr_add, instr_sub};
        is_slti_blt_slt <= |{instr_slti, instr_blt, instr_slt};
        is_sltiu_bltu_sltu <= |{instr_sltiu, instr_bltu, instr_sltu};
        is_lbu_lhu_lw <= |{instr_lbu, instr_lhu, instr_lw};
        is_compare <= |{is_beq_bne_blt_bge_bltu_bgeu,
                        instr_slti, instr_slt, instr_sltiu, instr_sltu};

        if (mem_do_rinst && mem_done) begin
            instr_lui   <= mem_rdata_latched[6:0] == 7'b0110111;
            instr_auipc <= mem_rdata_latched[6:0] == 7'b0010111;
            instr_jal   <= mem_rdata_latched[6:0] == 7'b1101111;
            instr_jalr  <= mem_rdata_latched[6:0] == 7'b1100111 &&
                           mem_rdata_latched[14:12] == 3'b000;

            is_beq_bne_blt_bge_bltu_bgeu <= mem_rdata_latched[6:0] == 7'b1100011;
            is_lb_lh_lw_lbu_lhu          <= mem_rdata_latched[6:0] == 7'b0000011;
            is_sb_sh_sw                  <= mem_rdata_latched[6:0] == 7'b0100011;
            is_alu_reg_imm               <= mem_rdata_latched[6:0] == 7'b0010011;
            is_alu_reg_reg               <= mem_rdata_latched[6:0] == 7'b0110011;

            {decoded_imm_j[31:20], decoded_imm_j[10:1], decoded_imm_j[11],
             decoded_imm_j[19:12], decoded_imm_j[0]} <=
                $signed({mem_rdata_latched[31:12], 1'b0});

            decoded_rd  <= mem_rdata_latched[11:7];
            decoded_rs1 <= mem_rdata_latched[19:15];
            decoded_rs2 <= mem_rdata_latched[24:20];
        end

        if (decoder_trigger && !decoder_pseudo_trigger) begin
            instr_beq  <= is_beq_bne_blt_bge_bltu_bgeu && next_insn_opcode[14:12] == 3'b000;
            instr_bne  <= is_beq_bne_blt_bge_bltu_bgeu && next_insn_opcode[14:12] == 3'b001;
            instr_blt  <= is_beq_bne_blt_bge_bltu_bgeu && next_insn_opcode[14:12] == 3'b100;
            instr_bge  <= is_beq_bne_blt_bge_bltu_bgeu && next_insn_opcode[14:12] == 3'b101;
            instr_bltu <= is_beq_bne_blt_bge_bltu_bgeu && next_insn_opcode[14:12] == 3'b110;
            instr_bgeu <= is_beq_bne_blt_bge_bltu_bgeu && next_insn_opcode[14:12] == 3'b111;

            instr_lb  <= is_lb_lh_lw_lbu_lhu && next_insn_opcode[14:12] == 3'b000;
            instr_lh  <= is_lb_lh_lw_lbu_lhu && next_insn_opcode[14:12] == 3'b001;
            instr_lw  <= is_lb_lh_lw_lbu_lhu && next_insn_opcode[14:12] == 3'b010;
            instr_lbu <= is_lb_lh_lw_lbu_lhu && next_insn_opcode[14:12] == 3'b100;
            instr_lhu <= is_lb_lh_lw_lbu_lhu && next_insn_opcode[14:12] == 3'b101;

            instr_sb <= is_sb_sh_sw && next_insn_opcode[14:12] == 3'b000;
            instr_sh <= is_sb_sh_sw && next_insn_opcode[14:12] == 3'b001;
            instr_sw <= is_sb_sh_sw && next_insn_opcode[14:12] == 3'b010;

            instr_addi  <= is_alu_reg_imm && next_insn_opcode[14:12] == 3'b000;
            instr_slti  <= is_alu_reg_imm && next_insn_opcode[14:12] == 3'b010;
            instr_sltiu <= is_alu_reg_imm && next_insn_opcode[14:12] == 3'b011;
            instr_xori  <= is_alu_reg_imm && next_insn_opcode[14:12] == 3'b100;
            instr_ori   <= is_alu_reg_imm && next_insn_opcode[14:12] == 3'b110;
            instr_andi  <= is_alu_reg_imm && next_insn_opcode[14:12] == 3'b111;

            instr_slli <= is_alu_reg_imm && next_insn_opcode[14:12] == 3'b001 &&
                          next_insn_opcode[31:25] == 7'b0000000;
            instr_srli <= is_alu_reg_imm && next_insn_opcode[14:12] == 3'b101 &&
                          next_insn_opcode[31:25] == 7'b0000000;
            instr_srai <= is_alu_reg_imm && next_insn_opcode[14:12] == 3'b101 &&
                          next_insn_opcode[31:25] == 7'b0100000;

            instr_add  <= is_alu_reg_reg && next_insn_opcode[14:12] == 3'b000 &&
                          next_insn_opcode[31:25] == 7'b0000000;
            instr_sub  <= is_alu_reg_reg && next_insn_opcode[14:12] == 3'b000 &&
                          next_insn_opcode[31:25] == 7'b0100000;
            instr_sll  <= is_alu_reg_reg && next_insn_opcode[14:12] == 3'b001 &&
                          next_insn_opcode[31:25] == 7'b0000000;
            instr_slt  <= is_alu_reg_reg && next_insn_opcode[14:12] == 3'b010 &&
                          next_insn_opcode[31:25] == 7'b0000000;
            instr_sltu <= is_alu_reg_reg && next_insn_opcode[14:12] == 3'b011 &&
                          next_insn_opcode[31:25] == 7'b0000000;
            instr_xor  <= is_alu_reg_reg && next_insn_opcode[14:12] == 3'b100 &&
                          next_insn_opcode[31:25] == 7'b0000000;
            instr_srl  <= is_alu_reg_reg && next_insn_opcode[14:12] == 3'b101 &&
                          next_insn_opcode[31:25] == 7'b0000000;
            instr_sra  <= is_alu_reg_reg && next_insn_opcode[14:12] == 3'b101 &&
                          next_insn_opcode[31:25] == 7'b0100000;
            instr_or   <= is_alu_reg_reg && next_insn_opcode[14:12] == 3'b110 &&
                          next_insn_opcode[31:25] == 7'b0000000;
            instr_and  <= is_alu_reg_reg && next_insn_opcode[14:12] == 3'b111 &&
                          next_insn_opcode[31:25] == 7'b0000000;

            instr_ecall_ebreak <= next_insn_opcode[6:0] == 7'b1110011 &&
                                  !next_insn_opcode[31:21] &&
                                  !next_insn_opcode[19:7];
            instr_fence <= next_insn_opcode[6:0] == 7'b0001111 &&
                           !next_insn_opcode[14:12];

            is_slli_srli_srai <= is_alu_reg_imm && |{
                next_insn_opcode[14:12] == 3'b001 && next_insn_opcode[31:25] == 7'b0000000,
                next_insn_opcode[14:12] == 3'b101 && next_insn_opcode[31:25] == 7'b0000000,
                next_insn_opcode[14:12] == 3'b101 && next_insn_opcode[31:25] == 7'b0100000
            };

            is_jalr_addi_slti_sltiu_xori_ori_andi <= instr_jalr ||
                is_alu_reg_imm && |{
                    next_insn_opcode[14:12] == 3'b000,
                    next_insn_opcode[14:12] == 3'b010,
                    next_insn_opcode[14:12] == 3'b011,
                    next_insn_opcode[14:12] == 3'b100,
                    next_insn_opcode[14:12] == 3'b110,
                    next_insn_opcode[14:12] == 3'b111
                };

            is_sll_srl_sra <= is_alu_reg_reg && |{
                next_insn_opcode[14:12] == 3'b001 && next_insn_opcode[31:25] == 7'b0000000,
                next_insn_opcode[14:12] == 3'b101 && next_insn_opcode[31:25] == 7'b0000000,
                next_insn_opcode[14:12] == 3'b101 && next_insn_opcode[31:25] == 7'b0100000
            };

            is_lui_auipc_jal_jalr_addi_add_sub <= 0;
            is_compare <= 0;

            case (1'b1)
                instr_jal:
                    decoded_imm <= decoded_imm_j;
                |{instr_lui, instr_auipc}:
                    decoded_imm <= next_insn_opcode[31:12] << 12;
                |{instr_jalr, is_lb_lh_lw_lbu_lhu, is_alu_reg_imm}:
                    decoded_imm <= $signed(next_insn_opcode[31:20]);
                is_beq_bne_blt_bge_bltu_bgeu:
                    decoded_imm <= $signed({next_insn_opcode[31], next_insn_opcode[7],
                                           next_insn_opcode[30:25], next_insn_opcode[11:8], 1'b0});
                is_sb_sh_sw:
                    decoded_imm <= $signed({next_insn_opcode[31:25], next_insn_opcode[11:7]});
                default:
                    decoded_imm <= 32'bx;
            endcase
        end

        if (!resetn) begin
            is_beq_bne_blt_bge_bltu_bgeu <= 0;
            is_compare <= 0;

            instr_beq <= 0; instr_bne <= 0; instr_blt <= 0; instr_bge <= 0;
            instr_bltu <= 0; instr_bgeu <= 0;
            instr_addi <= 0; instr_slti <= 0; instr_sltiu <= 0;
            instr_xori <= 0; instr_ori <= 0; instr_andi <= 0;
            instr_add <= 0; instr_sub <= 0; instr_sll <= 0; instr_slt <= 0;
            instr_sltu <= 0; instr_xor <= 0; instr_srl <= 0; instr_sra <= 0;
            instr_or <= 0; instr_and <= 0;
            instr_fence <= 0;
        end
    end

    // ------------------------------------------------------------------------
    // Main state machine and ALU
    // ------------------------------------------------------------------------

    localparam [7:0] CPU_TRAP  = 8'b10000000;
    localparam [7:0] CPU_FETCH = 8'b01000000;
    localparam [7:0] CPU_RS1   = 8'b00100000;
    localparam [7:0] CPU_EXEC  = 8'b00001000;
    localparam [7:0] CPU_SHIFT = 8'b00000100;
    localparam [7:0] CPU_STORE = 8'b00000010;
    localparam [7:0] CPU_LOAD  = 8'b00000001;

    reg [7:0] cpu_state;

    reg set_mem_do_rinst, set_mem_do_rdata, set_mem_do_wdata;
    reg latched_store, latched_stalu, latched_branch;
    reg latched_is_lu, latched_is_lh, latched_is_lb;
    reg [4:0] latched_rd;

    reg [31:0] current_pc;
    assign next_pc = latched_store && latched_branch
                        ? reg_out & ~1
                        : reg_next_pc;

    reg [31:0] alu_out, alu_out_q;
    reg        alu_out_0;
    reg [31:0] alu_add_sub;
    reg        alu_eq, alu_ltu, alu_lts;

    always @* begin
        alu_add_sub = instr_sub ? reg_op1 - reg_op2 : reg_op1 + reg_op2;
        alu_eq = reg_op1 == reg_op2;
        alu_lts = $signed(reg_op1) < $signed(reg_op2);
        alu_ltu = reg_op1 < reg_op2;
    end

    always @* begin
        alu_out_0 = 1'bx;
        case (1'b1)
            instr_beq: alu_out_0 = alu_eq;
            instr_bne: alu_out_0 = !alu_eq;
            instr_bge: alu_out_0 = !alu_lts;
            instr_bgeu: alu_out_0 = !alu_ltu;
            is_slti_blt_slt: alu_out_0 = alu_lts;
            is_sltiu_bltu_sltu: alu_out_0 = alu_ltu;
        endcase

        alu_out = 32'bx;
        case (1'b1)
            is_lui_auipc_jal_jalr_addi_add_sub: alu_out = alu_add_sub;
            is_compare:                         alu_out = {31'b0, alu_out_0};
            instr_xori || instr_xor:            alu_out = reg_op1 ^ reg_op2;
            instr_ori  || instr_or:             alu_out = reg_op1 | reg_op2;
            instr_andi || instr_and:            alu_out = reg_op1 & reg_op2;
        endcase
    end

    wire [31:0] cpuregs_rs1 = decoded_rs1 ? cpuregs[decoded_rs1] : 0;
    wire [31:0] cpuregs_rs2 = decoded_rs2 ? cpuregs[decoded_rs2] : 0;

    reg        cpuregs_write;
    reg [31:0] cpuregs_wrdata;

    always @* begin
        cpuregs_write = 0;
        cpuregs_wrdata = 32'bx;

        if (cpu_state == CPU_FETCH) begin
            case (1'b1)
                latched_branch: begin
                    cpuregs_wrdata = reg_pc + 4;
                    cpuregs_write = 1;
                end
                latched_store && !latched_branch: begin
                    cpuregs_wrdata = latched_stalu ? alu_out_q : reg_out;
                    cpuregs_write = 1;
                end
            endcase
        end
    end

    always @(posedge clk)
        if (resetn && cpuregs_write && latched_rd)
            cpuregs[latched_rd] <= cpuregs_wrdata;

    wire launch_next_insn = cpu_state == CPU_FETCH && decoder_trigger;

    always @(posedge clk) begin
        trap <= 0;
        reg_sh <= 5'bx;
        reg_out <= 32'bx;
        set_mem_do_rinst = 0;
        set_mem_do_rdata = 0;
        set_mem_do_wdata = 0;
        alu_out_q <= alu_out;

        decoder_trigger <= mem_do_rinst && mem_done;
        decoder_pseudo_trigger <= 0;

        if (!resetn) begin
            reg_pc <= PROGADDR_RESET;
            reg_next_pc <= PROGADDR_RESET;
            latched_store <= 0;
            latched_stalu <= 0;
            latched_branch <= 0;
            latched_is_lu <= 0;
            latched_is_lh <= 0;
            latched_is_lb <= 0;

            if (~STACKADDR) begin
                latched_store <= 1;
                latched_rd <= 2;
                reg_out <= STACKADDR;
            end

            cpu_state <= CPU_FETCH;
        end else begin
            case (cpu_state)
                CPU_TRAP: begin
                    trap <= 1;
                end

                CPU_FETCH: begin
                    mem_do_rinst <= !decoder_trigger;
                    mem_wordsize <= 0;

                    current_pc = reg_next_pc;

                    if (latched_branch)
                        current_pc = latched_store
                                   ? (latched_stalu ? alu_out_q : reg_out) & ~1
                                   : reg_next_pc;

                    reg_pc <= current_pc;
                    reg_next_pc <= current_pc;

                    latched_store <= 0;
                    latched_stalu <= 0;
                    latched_branch <= 0;
                    latched_is_lu <= 0;
                    latched_is_lh <= 0;
                    latched_is_lb <= 0;
                    latched_rd <= decoded_rd;

                    if (decoder_trigger) begin
                        reg_next_pc <= current_pc + 4;
                        if (instr_jal) begin
                            mem_do_rinst <= 1;
                            reg_next_pc <= current_pc + decoded_imm_j;
                            latched_branch <= 1;
                        end else begin
                            mem_do_rinst <= 0;
                            mem_do_prefetch <= !instr_jalr;
                            cpu_state <= CPU_RS1;
                        end
                    end
                end

                CPU_RS1: begin
                    reg_op1 <= 32'bx;
                    reg_op2 <= 32'bx;

                    case (1'b1)
                        instr_trap: begin
                            cpu_state <= CPU_TRAP;
                        end

                        is_lui_auipc_jal: begin
                            reg_op1 <= instr_lui ? 0 : reg_pc;
                            reg_op2 <= decoded_imm;
                            mem_do_rinst <= mem_do_prefetch;
                            cpu_state <= CPU_EXEC;
                        end

                        is_lb_lh_lw_lbu_lhu && !instr_trap: begin
                            reg_op1 <= cpuregs_rs1;
                            cpu_state <= CPU_LOAD;
                            mem_do_rinst <= 1;
                        end

                        is_slli_srli_srai: begin
                            reg_op1 <= cpuregs_rs1;
                            reg_sh <= decoded_rs2;
                            cpu_state <= CPU_SHIFT;
                        end

                        is_jalr_addi_slti_sltiu_xori_ori_andi: begin
                            reg_op1 <= cpuregs_rs1;
                            reg_op2 <= decoded_imm;
                            mem_do_rinst <= mem_do_prefetch;
                            cpu_state <= CPU_EXEC;
                        end

                        default: begin
                            reg_op1 <= cpuregs_rs1;
                            reg_sh <= cpuregs_rs2;
                            reg_op2 <= cpuregs_rs2;
                            case (1'b1)
                                is_sb_sh_sw: begin
                                    cpu_state <= CPU_STORE;
                                    mem_do_rinst <= 1;
                                end
                                is_sll_srl_sra: begin
                                    cpu_state <= CPU_SHIFT;
                                end
                                default: begin
                                    mem_do_rinst <= mem_do_prefetch;
                                    cpu_state <= CPU_EXEC;
                                end
                            endcase
                        end
                    endcase
                end

                CPU_EXEC: begin
                    reg_out <= reg_pc + decoded_imm;
                    if (is_beq_bne_blt_bge_bltu_bgeu) begin
                        latched_rd <= 0;
                        latched_store <= alu_out_0;
                        latched_branch <= alu_out_0;
                        if (mem_done)
                            cpu_state <= CPU_FETCH;
                        if (alu_out_0) begin
                            decoder_trigger <= 0;
                            set_mem_do_rinst = 1;
                        end
                    end else begin
                        latched_branch <= instr_jalr;
                        latched_store <= 1;
                        latched_stalu <= 1;
                        cpu_state <= CPU_FETCH;
                    end
                end

                CPU_SHIFT: begin
                    latched_store <= 1;
                    if (reg_sh == 0) begin
                        reg_out <= reg_op1;
                        mem_do_rinst <= mem_do_prefetch;
                        cpu_state <= CPU_FETCH;
                    end else if (TWO_STAGE_SHIFT && reg_sh >= 4) begin
                        case (1'b1)
                            instr_slli || instr_sll: reg_op1 <= reg_op1 << 4;
                            instr_srli || instr_srl: reg_op1 <= reg_op1 >> 4;
                            instr_srai || instr_sra: reg_op1 <= $signed(reg_op1) >>> 4;
                        endcase
                        reg_sh <= reg_sh - 4;
                    end else begin
                        case (1'b1)
                            instr_slli || instr_sll: reg_op1 <= reg_op1 << 1;
                            instr_srli || instr_srl: reg_op1 <= reg_op1 >> 1;
                            instr_srai || instr_sra: reg_op1 <= $signed(reg_op1) >>> 1;
                        endcase
                        reg_sh <= reg_sh - 1;
                    end
                end

                CPU_STORE: begin
                    if (!mem_do_prefetch || mem_done) begin
                        if (!mem_do_wdata) begin
                            case (1'b1)
                                instr_sb: mem_wordsize <= 2;
                                instr_sh: mem_wordsize <= 1;
                                instr_sw: mem_wordsize <= 0;
                            endcase
                            reg_op1 <= reg_op1 + decoded_imm;
                            set_mem_do_wdata = 1;
                        end
                        if (!mem_do_prefetch && mem_done) begin
                            cpu_state <= CPU_FETCH;
                            decoder_trigger <= 1;
                            decoder_pseudo_trigger <= 1;
                        end
                    end
                end

                CPU_LOAD: begin
                    latched_store <= 1;
                    if (!mem_do_prefetch || mem_done) begin
                        if (!mem_do_rdata) begin
                            case (1'b1)
                                instr_lb || instr_lbu: mem_wordsize <= 2;
                                instr_lh || instr_lhu: mem_wordsize <= 1;
                                instr_lw: mem_wordsize <= 0;
                            endcase
                            latched_is_lu <= is_lbu_lhu_lw;
                            latched_is_lh <= instr_lh;
                            latched_is_lb <= instr_lb;
                            reg_op1 <= reg_op1 + decoded_imm;
                            set_mem_do_rdata = 1;
                        end
                        if (!mem_do_prefetch && mem_done) begin
                            case (1'b1)
                                latched_is_lu: reg_out <= mem_rdata_word;
                                latched_is_lh: reg_out <= $signed(mem_rdata_word[15:0]);
                                latched_is_lb: reg_out <= $signed(mem_rdata_word[7:0]);
                            endcase
                            decoder_trigger <= 1;
                            decoder_pseudo_trigger <= 1;
                            cpu_state <= CPU_FETCH;
                        end
                    end
                end

                default: cpu_state <= CPU_TRAP;
            endcase
        end

        if (CATCH_MISALIGN && resetn && (mem_do_rdata || mem_do_wdata)) begin
            if (mem_wordsize == 0 && reg_op1[1:0] != 0)
                cpu_state <= CPU_TRAP;
            if (mem_wordsize == 1 && reg_op1[0] != 0)
                cpu_state <= CPU_TRAP;
        end

        if (CATCH_MISALIGN && resetn && mem_do_rinst && |reg_pc[1:0])
            cpu_state <= CPU_TRAP;

        if (!resetn || mem_done) begin
            mem_do_prefetch <= 0;
            mem_do_rinst <= 0;
            mem_do_rdata <= 0;
            mem_do_wdata <= 0;
        end

        if (set_mem_do_rinst)
            mem_do_rinst <= 1;
        if (set_mem_do_rdata)
            mem_do_rdata <= 1;
        if (set_mem_do_wdata)
            mem_do_wdata <= 1;

        current_pc = 32'bx;
    end

endmodule

/*
 * PicoRV32-derived work
 *
 * Original PicoRV32:
 * Copyright (C) 2015 - 2021 Claire Xenia Wolf <claire@yosyshq.com>
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * SPDX-License-Identifier: ISC
 */
