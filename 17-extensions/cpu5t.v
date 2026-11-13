`timescale 1ns/1ps
// ===========================================================================
//  Lesson 17 — the pipelined core, with privileged state.
//
//  THIS IS LESSON 16'S CORE. The honest way to read it is
//
//      diff cpu5t.v ../16-rv32i-pipeline/cpu5.v
//
//  and the diff is the lesson: five stages, the same forwarding network, the
//  same hazard logic, plus four things.
//
//    1. A SECOND DECODER (decode_ext.v) claims the instructions lesson 12
//       called illegal: the CSR instructions, ECALL, EBREAK, MRET and the M
//       extension.
//
//    2. TRAPS. An illegal instruction no longer halts the machine -- it is
//       REPORTED, to a handler, at an address the software chose. Taking a
//       trap is a redirect with bookkeeping: save where we were, say why,
//       turn interrupts off, jump to mtvec.
//
//    3. INTERRUPTS. The same mechanism, started by something OUTSIDE the
//       instruction stream. That is the whole difference between an exception
//       and an interrupt, and it is one input wire.
//
//    4. A STAGE THAT CAN TAKE LONGER THAN A CYCLE. The divider needs 32, so
//       for the first time in this course EX can say "not yet" -- which needs
//       a new kind of stall, holding the instruction IN EX rather than ahead
//       of it.
//
//  WHERE A TRAP IS TAKEN, AND WHY IT IS PRECISE
//
//  Traps are decided in ID, before the instruction has done anything. So:
//  everything AHEAD of it in the pipeline (EX, MEM, WB) completes normally,
//  because those instructions are earlier in program order; the trapping
//  instruction itself is squashed, having changed nothing; and everything
//  behind it is flushed by the redirect. The machine stops between two
//  instructions, exactly, with mepc naming the boundary.
//
//  That property is called PRECISION and it is not optional: without it a
//  handler cannot know what has happened, and returning from a trap is
//  impossible. It is also the hardest thing about traps in a deep pipeline,
//  and the reason real cores carry an exception down the stages with its
//  instruction and raise it at commit. Five stages and in-order completion is
//  what lets this core get away with deciding in ID.
// ===========================================================================
module cpu5t (
    input  wire        clk,
    input  wire        rst,

    // instruction memory: synchronous read, with a clock enable
    output wire [31:0] imem_addr,
    output wire        imem_en,
    input  wire [31:0] imem_data,

    // data memory: synchronous read, byte-enabled write
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_be,
    output wire        dmem_we,
    output wire        dmem_re,
    input  wire [31:0] dmem_rdata,

    // the machine timer, from outside: this is the whole of an interrupt
    input  wire        mtip,

    // visible state
    output wire [31:0] pc_out,
    output wire        trap_out,        // a trap was taken this cycle
    output wire [31:0] mcause_out,
    output wire        retire_out
);
    localparam [1:0] WB_ALU = 2'd0, WB_MEM = 2'd1, WB_PC4 = 2'd2;

    // RISC-V machine-mode trap causes. The top bit says "interrupt", which is
    // why mcause is 32 bits wide to hold numbers smaller than sixteen.
    localparam [31:0] CAUSE_ILLEGAL = 32'd2,
                      CAUSE_BREAK   = 32'd3,
                      CAUSE_ECALL_M = 32'd11,
                      CAUSE_TIMER   = 32'h8000_0007;

    // =======================================================================
    //  IF
    // =======================================================================
    reg [31:0] pc = 32'd0;

    wire        stall_id;        // load-use: ID waits, a bubble goes to EX
    wire        stall_ex;        // the divider: EX waits, and so does ID
    wire        freeze = stall_id || stall_ex;

    wire        redirect;        // a taken branch or jump, from EX
    wire [31:0] redirect_pc;
    wire        trap_redirect;   // a trap or an MRET, from ID
    wire [31:0] trap_pc_target;

    wire        go = redirect || trap_redirect;

    assign imem_addr = pc;
    assign imem_en   = go || !freeze;
    assign pc_out    = pc;

    wire [31:0] pc_next = redirect      ? redirect_pc    :
                          trap_redirect ? trap_pc_target :
                                          pc + 32'd4;

    always @(posedge clk)
        if (rst)             pc <= 32'd0;
        else if (go)         pc <= pc_next;
        else if (!freeze)    pc <= pc_next;

    // =======================================================================
    //  IF/ID
    // =======================================================================
    reg [31:0] id_pc    = 32'd0;
    reg        id_valid = 1'b0;

    always @(posedge clk)
        if (rst) begin
            id_pc    <= 32'd0;
            id_valid <= 1'b0;
        end else if (go) begin
            id_pc    <= pc;
            id_valid <= 1'b0;
        end else if (!freeze) begin
            id_pc    <= pc;
            id_valid <= 1'b1;
        end

    // =======================================================================
    //  ID — decode, read registers, and decide about traps
    // =======================================================================
    wire [31:0] id_inst = imem_data;

    wire [4:0]  id_rs1a, id_rs2a, id_rda;
    wire        id_reg_we_base, id_alu_a_pc, id_alu_a_zero, id_alu_b_imm;
    wire        id_mem_read, id_mem_write, id_branch, id_jump, id_jalr;
    wire        id_illegal_base;
    wire [3:0]  id_alu_op;
    wire [2:0]  id_funct3;
    wire [1:0]  id_wb_src;
    wire [31:0] id_imm;

    immgen u_imm (.inst(id_inst), .imm(id_imm));

    decode u_dec (
        .inst(id_inst),
        .rs1(id_rs1a), .rs2(id_rs2a), .rd(id_rda), .reg_we(id_reg_we_base),
        .alu_op(id_alu_op), .alu_a_pc(id_alu_a_pc), .alu_a_zero(id_alu_a_zero),
        .alu_b_imm(id_alu_b_imm),
        .mem_read(id_mem_read), .mem_write(id_mem_write), .mem_op(id_funct3),
        .branch(id_branch), .jump(id_jump), .jalr(id_jalr),
        .wb_src(id_wb_src), .illegal(id_illegal_base));

    // ---- the second decoder ------------------------------------------------
    wire        id_is_csr, id_csr_imm, id_is_ecall, id_is_ebreak, id_is_mret;
    wire [1:0]  id_csr_op;
    wire [11:0] id_csr_addr;
    wire [4:0]  id_csr_zimm;
    wire        id_is_mul, id_is_div;
    wire [2:0]  id_md_op;
    wire        id_ext_legal, id_ext_reg_we;

    decode_ext u_ext (
        .inst(id_inst),
        .is_csr(id_is_csr), .csr_op(id_csr_op), .csr_imm(id_csr_imm),
        .csr_addr(id_csr_addr), .csr_zimm(id_csr_zimm),
        .is_ecall(id_is_ecall), .is_ebreak(id_is_ebreak), .is_mret(id_is_mret),
        .is_mul(id_is_mul), .is_div(id_is_div), .md_op(id_md_op),
        .ext_legal(id_ext_legal), .ext_reg_we(id_ext_reg_we));

    // Lesson 12's verdict, overruled where this lesson has an answer.
    wire id_illegal = id_illegal_base && !id_ext_legal;
    wire id_reg_we  = id_reg_we_base  ||  id_ext_reg_we;

    // What this instruction NEEDS, for the stall logic. CSRRWI and friends
    // take a 5-bit immediate where rs1 would be, so they read no register --
    // stalling for one would be a bubble bought for nothing.
    localparam [6:0] OP_LUI = 7'b0110111, OP_AUIPC = 7'b0010111,
                     OP_JAL = 7'b1101111, OP_REG   = 7'b0110011,
                     OP_STORE = 7'b0100011, OP_BRANCH = 7'b1100011,
                     OP_SYSTEM = 7'b1110011;

    wire [6:0] id_op = id_inst[6:0];
    wire id_uses_rs1 = !(id_op == OP_LUI || id_op == OP_AUIPC ||
                         id_op == OP_JAL || (id_op == OP_SYSTEM && !id_is_csr) ||
                         (id_is_csr && id_csr_imm));
    wire id_uses_rs2 = (id_op == OP_REG) || (id_op == OP_STORE) ||
                       (id_op == OP_BRANCH);

    // ---- the register file, with lesson 16's bypass ------------------------
    wire [31:0] rf_rd1, rf_rd2;
    wire        wb_we;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;

    regfile #(.W(32), .N(32)) u_rf (
        .clk(clk),
        .rs1(id_rs1a), .rs2(id_rs2a), .rd1(rf_rd1), .rd2(rf_rd2),
        .we(wb_we), .rd(wb_rd), .wdata(wb_data));

    wire wb_hit_rs1 = wb_we && (wb_rd != 5'd0) && (wb_rd == id_rs1a);
    wire wb_hit_rs2 = wb_we && (wb_rd != 5'd0) && (wb_rd == id_rs2a);

    wire [31:0] id_rs1v = wb_hit_rs1 ? wb_data : rf_rd1;
    wire [31:0] id_rs2v = wb_hit_rs2 ? wb_data : rf_rd2;

    // ---- traps -------------------------------------------------------------
    //
    // `!redirect` is lesson 16's rule, and here it stops being a detail about
    // illegal instructions and becomes the thing that keeps traps precise: an
    // instruction on the wrong path of a branch must not trap, because it is
    // not going to run.
    //
    // `!stall_ex` defers a trap while the divider is working. The divide is an
    // EARLIER instruction and must finish; deferring the trap by a few cycles
    // changes nothing a handler can observe, and it keeps this logic from
    // having to reason about a half-finished instruction behind it.
    wire        irq_ready;
    wire [31:0] csr_mtvec, csr_mepc;

    // `!freeze` is doing more work than it looks. Besides the divider, it
    // covers the CSR serialisation below: a trap decided in this cycle reads
    // mtvec and mstatus, and if a CSR instruction one stage ahead is about to
    // change either of them, this cycle's answer is the stale one.
    wire trap_ok     = id_valid && !redirect && !freeze;

    wire take_irq     = trap_ok && irq_ready;
    wire take_illegal = trap_ok && id_illegal;
    wire take_ecall   = trap_ok && id_is_ecall;
    wire take_break   = trap_ok && id_is_ebreak;
    wire do_mret      = trap_ok && id_is_mret;

    // An interrupt wins over an exception raised by the same instruction. The
    // instruction has not run, so its exception will happen again when the
    // handler returns -- whereas an interrupt kept waiting is latency nobody
    // asked for.
    wire trap_take = take_irq || take_illegal || take_ecall || take_break;

    wire [31:0] trap_cause = take_irq     ? CAUSE_TIMER   :
                             take_illegal ? CAUSE_ILLEGAL :
                             take_break   ? CAUSE_BREAK   :
                                            CAUSE_ECALL_M;

    // mtval carries the detail a handler cannot otherwise get: for an illegal
    // instruction, the instruction itself, so a handler can emulate it.
    wire [31:0] trap_val = take_illegal ? id_inst :
                           take_break   ? id_pc   : 32'd0;

    assign trap_redirect  = trap_take || do_mret;
    assign trap_pc_target = trap_take ? csr_mtvec : csr_mepc;
    assign trap_out       = trap_take;

    // =======================================================================
    //  ID/EX
    // =======================================================================
    reg         ex_valid = 0;
    reg [31:0]  ex_pc = 0, ex_imm = 0, ex_rs1v = 0, ex_rs2v = 0;
    reg [4:0]   ex_rs1a = 0, ex_rs2a = 0, ex_rd = 0;
    reg [3:0]   ex_alu_op = 0;
    reg [2:0]   ex_funct3 = 0;
    reg [1:0]   ex_wb_src = 0;
    reg         ex_alu_a_pc = 0, ex_alu_a_zero = 0, ex_alu_b_imm = 0;
    reg         ex_reg_we = 0, ex_mem_read = 0, ex_mem_write = 0;
    reg         ex_branch = 0, ex_jump = 0, ex_jalr = 0;
    reg         ex_is_csr = 0, ex_csr_imm = 0, ex_is_mul = 0, ex_is_div = 0;
    reg [1:0]   ex_csr_op = 0;
    reg [11:0]  ex_csr_addr = 0;
    reg [4:0]   ex_csr_zimm = 0;
    reg [2:0]   ex_md_op = 0;
    reg         ex_uses_rs1 = 0, ex_uses_rs2 = 0;

    wire bubble = !id_valid || stall_id || go;

    always @(posedge clk)
        if (rst) begin
            ex_valid <= 0; ex_reg_we <= 0; ex_mem_write <= 0; ex_mem_read <= 0;
            ex_branch <= 0; ex_jump <= 0; ex_jalr <= 0;
            ex_is_csr <= 0; ex_is_mul <= 0; ex_is_div <= 0;
        end else if (stall_ex) begin
            // HOLD. The instruction in EX has not finished, so nothing moves
            // into EX and nothing in it changes. This is the one stall in the
            // course that freezes a stage rather than feeding it a bubble,
            // and the difference is which instruction is waiting.
            ex_valid <= ex_valid;
        end else begin
            ex_valid     <= !bubble;
            ex_reg_we    <= !bubble && id_reg_we;
            ex_mem_read  <= !bubble && id_mem_read;
            ex_mem_write <= !bubble && id_mem_write;
            ex_branch    <= !bubble && id_branch;
            ex_jump      <= !bubble && id_jump;
            ex_jalr      <= !bubble && id_jalr;
            ex_is_csr    <= !bubble && id_is_csr;
            ex_is_mul    <= !bubble && id_is_mul;
            ex_is_div    <= !bubble && id_is_div;

            ex_pc        <= id_pc;
            ex_imm       <= id_imm;
            ex_rs1v      <= id_rs1v;
            ex_rs2v      <= id_rs2v;
            ex_rs1a      <= id_rs1a;
            ex_rs2a      <= id_rs2a;
            ex_rd        <= id_rda;
            ex_alu_op    <= id_alu_op;
            ex_funct3    <= id_funct3;
            ex_wb_src    <= id_wb_src;
            ex_alu_a_pc  <= id_alu_a_pc;
            ex_alu_a_zero<= id_alu_a_zero;
            ex_alu_b_imm <= id_alu_b_imm;
            ex_csr_op    <= id_csr_op;
            ex_csr_imm   <= id_csr_imm;
            ex_csr_addr  <= id_csr_addr;
            ex_csr_zimm  <= id_csr_zimm;
            ex_md_op     <= id_md_op;
            ex_uses_rs1  <= id_uses_rs1;
            ex_uses_rs2  <= id_uses_rs2;
        end

    // =======================================================================
    //  EX
    // =======================================================================
    reg         m_valid = 0, m_reg_we = 0, m_mem_read = 0, m_mem_write = 0;
    reg [1:0]   m_wb_src = 0;
    reg [2:0]   m_funct3 = 0;
    reg [31:0]  m_alu = 0, m_pc4 = 0, m_rs2v = 0;
    reg [4:0]   m_rd = 0;

    reg         w_valid = 0, w_reg_we = 0;
    reg [1:0]   w_wb_src = 0;
    reg [2:0]   w_funct3 = 0;
    reg [1:0]   w_addr_lo = 0;
    reg [31:0]  w_alu = 0, w_pc4 = 0;
    reg [4:0]   w_rd = 0;

    wire [31:0] mem_fwd = (m_wb_src == WB_PC4) ? m_pc4 : m_alu;

    wire fwd_m_rs1 = m_valid && m_reg_we && (m_rd != 5'd0) &&
                     (m_rd == ex_rs1a) && (m_wb_src != WB_MEM);
    wire fwd_m_rs2 = m_valid && m_reg_we && (m_rd != 5'd0) &&
                     (m_rd == ex_rs2a) && (m_wb_src != WB_MEM);
    wire fwd_w_rs1 = w_valid && w_reg_we && (w_rd != 5'd0) && (w_rd == ex_rs1a);
    wire fwd_w_rs2 = w_valid && w_reg_we && (w_rd != 5'd0) && (w_rd == ex_rs2a);

    wire [31:0] ex_a_src = fwd_m_rs1 ? mem_fwd :
                           fwd_w_rs1 ? wb_data : ex_rs1v;
    wire [31:0] ex_b_src = fwd_m_rs2 ? mem_fwd :
                           fwd_w_rs2 ? wb_data : ex_rs2v;

    wire [31:0] alu_a = ex_alu_a_zero ? 32'd0 :
                        ex_alu_a_pc   ? ex_pc : ex_a_src;
    wire [31:0] alu_b = ex_alu_b_imm  ? ex_imm : ex_b_src;
    wire [31:0] alu_y;
    wire        alu_zero;

    alu #(.W(32)) u_alu (
        .op(ex_alu_op), .a(alu_a), .b(alu_b), .y(alu_y), .zero(alu_zero));

    wire taken_cond;
    branch_unit u_br (.a(ex_a_src), .b(ex_b_src), .funct3(ex_funct3),
                      .taken(taken_cond));

    wire [31:0] ex_pc4      = ex_pc + 32'd4;
    wire [31:0] br_target   = ex_pc + ex_imm;
    wire [31:0] jalr_target = (ex_a_src + ex_imm) & ~32'd1;

    assign redirect    = ex_valid && (ex_jump || ex_jalr ||
                                      (ex_branch && taken_cond));
    assign redirect_pc = ex_jalr ? jalr_target : br_target;

    // ---- the CSR file ------------------------------------------------------
    // The operand is the forwarded rs1, or a 5-bit immediate sitting in the
    // rs1 field. The immediate forms exist so that setting or clearing a
    // handful of bits -- which is most of what CSR code does -- costs no
    // register at all.
    wire [31:0] csr_operand = ex_csr_imm ? {27'd0, ex_csr_zimm} : ex_a_src;
    wire [31:0] csr_rdata;

    csr u_csr (
        .clk(clk), .rst(rst),
        .en(ex_valid && ex_is_csr && !stall_ex),
        .addr(ex_csr_addr), .op(ex_csr_op), .wdata(csr_operand),
        .rdata(csr_rdata),
        .trap(trap_take), .trap_pc(id_pc), .trap_cause(trap_cause),
        .trap_val(trap_val), .mtvec_out(csr_mtvec),
        .mret(do_mret), .mepc_out(csr_mepc),
        .mtip(mtip), .irq_ready(irq_ready),
        .retire(w_valid));

    assign mcause_out = trap_cause;

    // ---- multiply and divide ----------------------------------------------
    wire [31:0] mul_y, div_y;
    wire        mul_done, div_done;

    mul_unit u_mul (
        .clk(clk), .rst(rst),
        .req(ex_valid && ex_is_mul), .a(ex_a_src), .b(ex_b_src), .op(ex_md_op),
        .done(mul_done), .y(mul_y));

    div_unit u_div (
        .clk(clk), .rst(rst),
        .req(ex_valid && ex_is_div), .a(ex_a_src), .b(ex_b_src), .op(ex_md_op),
        .done(div_done), .y(div_y));

    // THE NEW STALL. Everything before this lesson finished EX in one cycle.
    // Two units can hold it up now and the stage does not care which: a
    // multiply for one cycle, a divide for thirty-two. "EX is not finished"
    // is one signal, which is why adding the second unit changed nothing
    // anywhere else in this file.
    assign stall_ex = ex_valid && ((ex_is_mul && !mul_done) ||
                                   (ex_is_div && !div_done));

    // ---- what EX produces --------------------------------------------------
    // One result wire, four possible producers. CSR reads, multiplies and
    // divides all travel to writeback in the ALU result's place, so the
    // forwarding network, the writeback mux and the hazard logic need to know
    // nothing about any of them.
    wire [31:0] ex_result = ex_is_csr ? csr_rdata :
                            ex_is_mul ? mul_y     :
                            ex_is_div ? div_y     : alu_y;

    // ---- the load-use stall, unchanged from lesson 16 ----------------------
    wire load_use = ex_valid && ex_mem_read && (ex_rd != 5'd0) && id_valid &&
                    ((id_uses_rs1 && (id_rs1a == ex_rd)) ||
                     (id_uses_rs2 && (id_rs2a == ex_rd)));

    // ---- and a new one: a CSR instruction SERIALISES ----------------------
    //
    // THE BUG THIS FIXES was the first thing that went wrong in this lesson,
    // and it is worth more than the four lines that fix it.
    //
    //     csrw  mtvec, a5        <- in EX, writing mtvec at the end of this cycle
    //     ecall                  <- in ID, reading mtvec to find out where to go
    //
    // Both in the machine at once, one stage apart. The ECALL read the OLD
    // mtvec -- zero, because nothing had set it yet -- and jumped to address
    // zero, which is the first instruction of the program. The machine
    // restarted itself, printed its greeting a second time, and carried on as
    // if nothing had happened. On the board that would look like a glitch.
    //
    // Lesson 16's forwarding network cannot help here. It forwards VALUES
    // between instructions, and this is not a value: it is a change to how
    // the machine BEHAVES -- where traps go, whether interrupts are allowed,
    // what the timer is compared against. There is no wire to forward "the
    // rules are different now" along.
    //
    // So the pipeline serialises instead: while a CSR instruction is in EX,
    // nothing is decoded behind it. One bubble per CSR instruction, which is
    // the right price for an instruction that executes a few dozen times in a
    // program's life -- and it is why real ISAs describe CSR writes as
    // serialising rather than as ordinary register writes.
    wire csr_serialise = ex_valid && ex_is_csr;

    assign stall_id = load_use || csr_serialise;

    // =======================================================================
    //  EX/MEM
    // =======================================================================
    always @(posedge clk)
        if (rst) begin
            m_valid <= 0; m_reg_we <= 0; m_mem_write <= 0; m_mem_read <= 0;
        end else if (stall_ex) begin
            // EX is still working, so MEM gets a bubble: there is nothing to
            // send it yet.
            m_valid     <= 0;
            m_reg_we    <= 0;
            m_mem_read  <= 0;
            m_mem_write <= 0;
        end else begin
            m_valid     <= ex_valid;
            m_reg_we    <= ex_valid && ex_reg_we;
            m_mem_read  <= ex_valid && ex_mem_read;
            m_mem_write <= ex_valid && ex_mem_write;
            m_wb_src    <= ex_wb_src;
            m_funct3    <= ex_funct3;
            m_alu       <= ex_result;
            m_pc4       <= ex_pc4;
            m_rs2v      <= ex_b_src;
            m_rd        <= ex_rd;
        end

    // =======================================================================
    //  MEM
    // =======================================================================
    store_align u_sa (
        .addr_lo(m_alu[1:0]), .funct3(m_funct3), .wdata(m_rs2v),
        .mem_wdata(dmem_wdata), .mem_be(dmem_be));

    assign dmem_addr = m_alu;
    assign dmem_we   = m_valid && m_mem_write;
    assign dmem_re   = m_valid && m_mem_read;

    // =======================================================================
    //  MEM/WB
    // =======================================================================
    always @(posedge clk)
        if (rst) begin
            w_valid <= 0; w_reg_we <= 0;
        end else begin
            w_valid   <= m_valid;
            w_reg_we  <= m_valid && m_reg_we;
            w_wb_src  <= m_wb_src;
            w_funct3  <= m_funct3;
            w_addr_lo <= m_alu[1:0];
            w_alu     <= m_alu;
            w_pc4     <= m_pc4;
            w_rd      <= m_rd;
        end

    // =======================================================================
    //  WB
    // =======================================================================
    wire [31:0] load_data;

    load_align u_la (
        .addr_lo(w_addr_lo), .funct3(w_funct3),
        .mem_rdata(dmem_rdata), .rdata(load_data));

    assign wb_data = (w_wb_src == WB_MEM) ? load_data :
                     (w_wb_src == WB_PC4) ? w_pc4 :
                                            w_alu;
    assign wb_we   = w_valid && w_reg_we;
    assign wb_rd   = w_rd;

    assign retire_out = w_valid;

    wire _unused = &{alu_zero, WB_ALU, 1'b0};

`ifndef SYNTHESIS
    always @(posedge clk)
        // Qualified by what the instruction actually READS. The rs1 field of
        // CSRRWI is not a register number at all -- it is a 5-bit immediate --
        // so comparing it against a destination register raises a false alarm,
        // which is exactly what it did the first time this lesson ran.
        if (!rst && m_valid && m_reg_we && (m_wb_src == WB_MEM) &&
            (m_rd != 5'd0) && ex_valid &&
            ((ex_uses_rs1 && m_rd == ex_rs1a) ||
             (ex_uses_rs2 && m_rd == ex_rs2a)))
            $display("ASSERT FAIL: load-use hazard reached EX unstalled (x%0d, pc %h)",
                     m_rd, ex_pc);
`endif
endmodule
