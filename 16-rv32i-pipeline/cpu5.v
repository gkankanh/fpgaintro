`timescale 1ns/1ps
// ===========================================================================
//  Lesson 16 — the same RV32I core, in five stages.
//
//      IF  ──> ID  ──> EX  ──> MEM ──> WB
//       │       │       │       │       │
//     fetch   decode   ALU    memory  register
//             + read   +      access  write
//             regs    branch
//
//  WHAT PIPELINING IS, IN ONE SENTENCE: the same work, cut into five pieces
//  with registers between them, so five instructions can be in the machine at
//  once and the clock period only has to cover the longest PIECE instead of
//  the whole chain.
//
//  Lesson 13's core did fetch, decode, read, compute, access memory and write
//  back between one clock edge and the next, and measured 61.24 MHz. Nothing
//  here makes any of those steps faster. The clock goes up because no single
//  step has to finish inside the same period as all the others.
//
//  WHAT IT COSTS. Three things, and all three are the subject of this file:
//
//    1. REGISTERS. Four sets of pipeline registers, holding everything a
//       half-finished instruction knows about itself. Lesson 13's whole core
//       had 32 flip-flops -- the program counter. This one has hundreds, and
//       that difference IS pipelining.
//
//    2. HAZARDS. Instruction N+1 may need a result instruction N has not
//       written yet. Three mechanisms handle it: forwarding (take the value
//       from where it already is), stalling (wait, when it does not exist
//       yet) and flushing (throw away instructions fetched from the wrong
//       place after a branch).
//
//    3. CPI ABOVE 1. The single-cycle core retired exactly one instruction
//       per cycle. This one retires one per cycle only when nothing goes
//       wrong, and the README measures how often that is.
//
//  WHAT DOES NOT CHANGE: the ALU is lesson 10's, the register file is lesson
//  11's, the decoder and immediate generator are lesson 12's, the branch
//  comparator and the load/store aligners are lesson 13's. Not one of those
//  files is touched. A pipeline is a different ARRANGEMENT of the same parts,
//  and lesson 14's proof of the ALU still holds for exactly that reason.
// ===========================================================================
module cpu5 (
    input  wire        clk,
    input  wire        rst,

    // ---- instruction memory: SYNCHRONOUS read, with a clock enable -------
    // The address goes out in one cycle and the instruction comes back in the
    // next. That is what a block RAM does, and being able to live with it is
    // the whole reason this core can use one (lesson 08).
    //
    // `imem_en` is the enable on the memory's OUTPUT register, and it is how
    // this core stalls: hold the enable low and the instruction register keeps
    // what it has, so the ID stage sees the same instruction again. The memory's
    // own output register IS the IF/ID pipeline register -- a real one, in the
    // block RAM, that costs nothing because it is already there.
    output wire [31:0] imem_addr,
    output wire        imem_en,
    input  wire [31:0] imem_data,

    // ---- data memory: synchronous read, byte-enabled write ---------------
    // Address out in MEM, data back in WB. `dmem_re` says this is a REAL
    // read -- the signal lesson 15's address decoder needed and could not
    // have, because the single-cycle core never knew which cycles were loads.
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_be,
    output wire        dmem_we,
    output wire        dmem_re,
    input  wire [31:0] dmem_rdata,

    // ---- visible state ----------------------------------------------------
    output wire [31:0] pc_out,
    output wire        illegal_out,
    output wire        retire_out        // one instruction completed, this cycle
);
    localparam [1:0] WB_ALU = 2'd0, WB_MEM = 2'd1, WB_PC4 = 2'd2;

    // =======================================================================
    //  IF — fetch
    // =======================================================================
    reg [31:0] pc = 32'd0;

    wire        stall;                   // load-use: hold IF and ID
    wire        redirect;                // branch or jump: throw away what we fetched
    wire [31:0] redirect_pc;
    wire        halt_ill;                // an illegal instruction stopped the machine

    assign imem_addr = pc;
    assign imem_en   = !halt_ill && (redirect || !stall);
    assign pc_out    = pc;

    wire [31:0] pc_next = redirect ? redirect_pc : pc + 32'd4;

    always @(posedge clk)
        if (rst)                              pc <= 32'd0;
        else if (halt_ill)                    pc <= pc;
        else if (redirect || !stall)          pc <= pc_next;

    // =======================================================================
    //  IF/ID — one register, because the instruction lives in the memory's
    //  output register and the only thing left to carry is which address it
    //  came from.
    // =======================================================================
    reg [31:0] id_pc    = 32'd0;
    reg        id_valid = 1'b0;

    always @(posedge clk)
        if (rst) begin
            id_pc    <= 32'd0;
            id_valid <= 1'b0;
        end else if (redirect) begin
            // The instruction arriving next cycle was fetched from after the
            // branch and must not run. Marking it invalid is the flush.
            id_pc    <= pc;
            id_valid <= 1'b0;
        end else if (!stall && !halt_ill) begin
            id_pc    <= pc;
            id_valid <= 1'b1;
        end

    // =======================================================================
    //  ID — decode, read registers
    // =======================================================================
    wire [31:0] id_inst = imem_data;

    wire [4:0]  id_rs1a, id_rs2a, id_rda;
    wire        id_reg_we, id_alu_a_pc, id_alu_a_zero, id_alu_b_imm;
    wire        id_mem_read, id_mem_write, id_branch, id_jump, id_jalr, id_illegal;
    wire [3:0]  id_alu_op;
    wire [2:0]  id_funct3;
    wire [1:0]  id_wb_src;
    wire [31:0] id_imm;

    immgen u_imm (.inst(id_inst), .imm(id_imm));

    decode u_dec (
        .inst(id_inst),
        .rs1(id_rs1a), .rs2(id_rs2a), .rd(id_rda), .reg_we(id_reg_we),
        .alu_op(id_alu_op), .alu_a_pc(id_alu_a_pc), .alu_a_zero(id_alu_a_zero),
        .alu_b_imm(id_alu_b_imm),
        .mem_read(id_mem_read), .mem_write(id_mem_write), .mem_op(id_funct3),
        .branch(id_branch), .jump(id_jump), .jalr(id_jalr),
        .wb_src(id_wb_src), .illegal(id_illegal));

    // ---- a question lesson 12's decoder was never asked --------------------
    //
    // "What does this instruction DO" was enough for a single-cycle core.
    // A pipeline also has to know "what does it NEED", because the answer
    // decides whether to stall. LUI has no rs1 -- lesson 13 learned that the
    // hard way -- and stalling for a register an instruction does not read
    // would be a bubble bought for nothing.
    //
    // These two lines belong in decode.v, honestly. They are here because
    // that file is a finished, measured artifact of lesson 12, and a lesson
    // that quietly rewrites an earlier lesson's module invalidates its
    // numbers. The cost of keeping them here is this paragraph.
    localparam [6:0] OP_LUI = 7'b0110111, OP_AUIPC = 7'b0010111,
                     OP_JAL = 7'b1101111, OP_REG   = 7'b0110011,
                     OP_STORE = 7'b0100011, OP_BRANCH = 7'b1100011;

    wire [6:0] id_op = id_inst[6:0];
    wire id_uses_rs1 = !(id_op == OP_LUI || id_op == OP_AUIPC || id_op == OP_JAL);
    wire id_uses_rs2 = (id_op == OP_REG) || (id_op == OP_STORE) || (id_op == OP_BRANCH);

    // ---- the register file, with the bypass lesson 11 predicted -----------
    //
    // Lesson 11's regfile has no write-to-read bypass, and its comment says
    // exactly why that was right then and wrong now: "Bypass becomes
    // necessary when a read and a write belong to DIFFERENT instructions in
    // flight at once. That is lesson 16's pipeline."
    //
    // Here is the case. An instruction in WB writes its result at the END of
    // this cycle; an instruction in ID reads the register file DURING this
    // cycle and would get the old value. They are four instructions apart --
    // too far for the EX forwarding below, too close for the write to have
    // landed. One mux on each read port fixes it.
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

    // A BUBBLE is not a special instruction. It is `valid` going low, with
    // every control signal that could change state forced off. Everything
    // else in the register may hold whatever it likes: nothing will look.
    wire bubble = !id_valid || stall || redirect || halt_ill;

    always @(posedge clk)
        if (rst) begin
            ex_valid <= 0; ex_reg_we <= 0; ex_mem_write <= 0; ex_mem_read <= 0;
            ex_branch <= 0; ex_jump <= 0; ex_jalr <= 0;
        end else begin
            ex_valid     <= !bubble;
            ex_reg_we    <= !bubble && id_reg_we;
            ex_mem_read  <= !bubble && id_mem_read;
            ex_mem_write <= !bubble && id_mem_write;
            ex_branch    <= !bubble && id_branch;
            ex_jump      <= !bubble && id_jump;
            ex_jalr      <= !bubble && id_jalr;

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
        end

    // =======================================================================
    //  EX — forward, compute, resolve branches
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

    // ---- forwarding --------------------------------------------------------
    //
    // "Do not wait for the value to arrive in the register file; take it from
    // wherever it already exists." Two places have it:
    //
    //   EX/MEM  the instruction one ahead. Its ALU result is already computed.
    //   MEM/WB  the instruction two ahead. Its result is whatever WB is about
    //           to write -- including a loaded word, which only exists now.
    //
    // The MEM-stage value of a LOAD is not its result, it is its ADDRESS, and
    // forwarding it would be a silent disaster. That case is the one the stall
    // below exists to prevent, and the assertion at the bottom of this file
    // checks that it never happens.
    wire [31:0] mem_fwd = (m_wb_src == WB_PC4) ? m_pc4 : m_alu;

    wire fwd_m_rs1 = m_valid && m_reg_we && (m_rd != 5'd0) &&
                     (m_rd == ex_rs1a) && (m_wb_src != WB_MEM);
    wire fwd_m_rs2 = m_valid && m_reg_we && (m_rd != 5'd0) &&
                     (m_rd == ex_rs2a) && (m_wb_src != WB_MEM);
    wire fwd_w_rs1 = w_valid && w_reg_we && (w_rd != 5'd0) && (w_rd == ex_rs1a);
    wire fwd_w_rs2 = w_valid && w_reg_we && (w_rd != 5'd0) && (w_rd == ex_rs2a);

    // EX/MEM wins over MEM/WB: when both have written the register, the nearer
    // instruction is the more recent one, and the more recent one is right.
    wire [31:0] ex_a_src = fwd_m_rs1 ? mem_fwd :
                           fwd_w_rs1 ? wb_data : ex_rs1v;
    wire [31:0] ex_b_src = fwd_m_rs2 ? mem_fwd :
                           fwd_w_rs2 ? wb_data : ex_rs2v;

    // ---- the ALU, exactly as lesson 13 wired it ---------------------------
    wire [31:0] alu_a = ex_alu_a_zero ? 32'd0 :
                        ex_alu_a_pc   ? ex_pc : ex_a_src;
    wire [31:0] alu_b = ex_alu_b_imm  ? ex_imm : ex_b_src;
    wire [31:0] alu_y;
    wire        alu_zero;

    alu #(.W(32)) u_alu (
        .op(ex_alu_op), .a(alu_a), .b(alu_b), .y(alu_y), .zero(alu_zero));

    // ---- branches, resolved here and not earlier --------------------------
    //
    // The comparison uses the FORWARDED operands, which is the whole reason a
    // branch cannot be resolved in ID without a second forwarding network:
    // in ID the values may not exist yet.
    //
    // Resolving in EX costs two wrong instructions on every taken branch --
    // the two already fetched behind it. Resolving in ID would cost one.
    // Predicting would cost none, when the prediction is right. This core
    // does the simplest correct thing and the README measures what it costs.
    wire taken_cond;
    branch_unit u_br (.a(ex_a_src), .b(ex_b_src), .funct3(ex_funct3),
                      .taken(taken_cond));

    wire [31:0] ex_pc4       = ex_pc + 32'd4;
    wire [31:0] br_target    = ex_pc + ex_imm;
    wire [31:0] jalr_target  = (ex_a_src + ex_imm) & ~32'd1;

    assign redirect    = ex_valid && (ex_jump || ex_jalr ||
                                      (ex_branch && taken_cond));
    assign redirect_pc = ex_jalr ? jalr_target : br_target;

    // ---- the one hazard forwarding cannot fix ------------------------------
    //
    // A load's result does not EXIST until WB: the memory is synchronous, so
    // the word asked for in MEM arrives in the cycle after. An instruction
    // that needs it one instruction later would have to read it a cycle
    // before it exists, and no amount of wiring moves a value backwards in
    // time. So: stall one cycle, and the forwarding network handles the rest.
    //
    // This is the load-use hazard, it costs exactly one bubble, and it is the
    // reason compilers bother to schedule an unrelated instruction into the
    // slot after a load.
    assign stall = ex_valid && ex_mem_read && (ex_rd != 5'd0) && id_valid &&
                   ((id_uses_rs1 && (id_rs1a == ex_rd)) ||
                    (id_uses_rs2 && (id_rs2a == ex_rd)));

    // =======================================================================
    //  EX/MEM
    // =======================================================================
    always @(posedge clk)
        if (rst) begin
            m_valid <= 0; m_reg_we <= 0; m_mem_write <= 0; m_mem_read <= 0;
        end else begin
            m_valid     <= ex_valid;
            m_reg_we    <= ex_valid && ex_reg_we;
            m_mem_read  <= ex_valid && ex_mem_read;
            m_mem_write <= ex_valid && ex_mem_write;
            m_wb_src    <= ex_wb_src;
            m_funct3    <= ex_funct3;
            m_alu       <= alu_y;
            m_pc4       <= ex_pc4;
            m_rs2v      <= ex_b_src;     // forwarded: a store's data, too
            m_rd        <= ex_rd;
        end

    // =======================================================================
    //  MEM — the only stage that talks to the outside
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
    //  WB — select the result and write it
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

    // =======================================================================
    //  Illegal instructions
    // =======================================================================
    // Lesson 13 froze the program counter. This does the same, one stage
    // earlier, and the machine simply stops with the offending PC visible.
    // That is not what a real processor does: it takes a TRAP, which needs
    // somewhere to record what happened and somewhere to jump to. Both of
    // those are lesson 17.
    //
    // ---------------------------------------------------------------------
    //  `&& !redirect` IS NOT A DETAIL. It is the first bug this core hit.
    //
    //  When EX resolves a taken branch or a jump, the instruction sitting in
    //  ID was fetched from after it and is on the WRONG PATH. It is already
    //  being discarded -- `bubble` includes `redirect`, so it never reaches
    //  EX. But an exception is not something an instruction DOES; it is
    //  something it IS, and this latch was looking at it anyway.
    //
    //  That costs nothing until the wrong-path word is not an instruction at
    //  all. The last instruction of main() is `jal`, and the word after it is
    //  the first four bytes of a string constant: "bss ". Decoded, that is an
    //  illegal instruction, and the machine halted on a word it was in the
    //  middle of throwing away.
    //
    //  The rule it taught, which every real processor obeys: AN INSTRUCTION
    //  THAT IS SQUASHED RAISES NOTHING. Real pipelines carry the exception
    //  down with the instruction and raise it at commit, for exactly this
    //  reason -- by then they know whether it was really going to run.
    reg ill = 0;
    always @(posedge clk)
        if (rst)                                           ill <= 0;
        else if (id_valid && id_illegal && !redirect) begin
            ill <= 1;
`ifndef SYNTHESIS
            $display("ILLEGAL: pc=%h inst=%h", id_pc, id_inst);
`endif
        end

    assign halt_ill    = ill;
    assign illegal_out = ill;

    // ---- signals this design deliberately does not use --------------------
    //   alu_zero  branches use the dedicated comparator, as in lesson 13.
    //   WB_ALU    named for readability; the writeback mux falls through to it.
    //   ex_rs2a / ex_rs1a are used by forwarding, ex_rs2v by the EX mux.
    wire _unused = &{alu_zero, WB_ALU, 1'b0};

    // ---- the assertion that guards the stall ------------------------------
    //
    // If the load-use stall were ever wrong, the forwarding network would
    // quietly hand out a load's ADDRESS in place of its result and the
    // machine would compute confident nonsense. This costs nothing in
    // hardware -- it is inside `ifndef SYNTHESIS` -- and it turns a silent
    // wrong answer into a line of output naming the cycle it happened in.
`ifndef SYNTHESIS
    always @(posedge clk)
        if (!rst && m_valid && m_reg_we && (m_wb_src == WB_MEM) &&
            (m_rd != 5'd0) && ex_valid &&
            ((m_rd == ex_rs1a) || (m_rd == ex_rs2a)))
            $display("ASSERT FAIL: load-use hazard reached EX unstalled (x%0d, pc %h)",
                     m_rd, ex_pc);
`endif
endmodule
