`timescale 1ns/1ps
// ===========================================================================
//  Lesson 13 — a single-cycle RV32I core.
//
//  Every instruction completes in ONE clock. The datapath, in the order the
//  data flows:
//
//    PC ──> instruction memory ──> decode ──┬──> register file ──┐
//                                           │                    ├─> ALU ──┐
//                                           └──> immgen ─────────┘         │
//                                                                          ├─> writeback
//                 data memory <──────── address ─────────────────┘         │
//                        └───────────────────────────────────────────────> ─┘
//
//    PC+4 ──┐
//    PC+imm ├──> next PC
//    rs1+imm┘
//
//  Nothing here is new. The ALU is lesson 10, the register file is lesson 11,
//  the decoder and immediate generator are lesson 12, the branch comparator
//  and the load/store aligners are this lesson's only new logic. A CPU is not
//  a new kind of thing -- it is a state machine (lesson 05) whose state is a
//  program counter, wired to parts you have already built and tested.
//
//  WHY SINGLE-CYCLE FIRST: because the datapath stays visible. There are no
//  pipeline registers between the stages, so every wire goes where the diagram
//  says it goes. Lesson 16 pipelines this exact core, and the comparison is
//  the point.
//
//  THE COST: everything above happens within one clock period, so the critical
//  path is the whole datapath in series. Lesson 10 measured the ALU alone at
//  116 MHz; by the time instruction fetch, register read, the ALU, the data
//  memory and the writeback mux are all on one path, the achievable clock is
//  far lower. That number is measured in the README.
//
//  Memories are external ports so the testbench can load programs and inspect
//  results. Both reads are COMBINATIONAL, which is what single-cycle requires
//  and what lesson 08 showed rules out block RAM -- see the README for what
//  that costs.
// ===========================================================================
module cpu (
    input  wire        clk,
    input  wire        rst,

    // instruction memory: combinational read
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_data,

    // data memory: combinational read, byte-enabled write
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_be,
    output wire        dmem_we,
    input  wire [31:0] dmem_rdata,

    // visible state, for the testbench and the board
    output wire [31:0] pc_out,
    output wire        illegal_out
);
    // ---- the program counter ----------------------------------------------
    reg [31:0] pc = 32'd0;
    assign pc_out    = pc;
    assign imem_addr = pc;

    wire [31:0] inst = imem_data;
    wire [31:0] pc4  = pc + 32'd4;

    // ---- decode (lesson 12) ------------------------------------------------
    wire [4:0]  rs1_a, rs2_a, rd_a;
    wire        reg_we, alu_a_pc, alu_a_zero, alu_b_imm, mem_read, mem_write;
    wire [3:0]  alu_op;
    wire [2:0]  mem_op;
    wire        branch, jump, jalr, illegal;
    wire [1:0]  wb_src;
    wire [31:0] imm;

    immgen u_imm (.inst(inst), .imm(imm));

    decode u_dec (
        .inst(inst),
        .rs1(rs1_a), .rs2(rs2_a), .rd(rd_a), .reg_we(reg_we),
        .alu_op(alu_op), .alu_a_pc(alu_a_pc), .alu_a_zero(alu_a_zero),
        .alu_b_imm(alu_b_imm),
        .mem_read(mem_read), .mem_write(mem_write), .mem_op(mem_op),
        .branch(branch), .jump(jump), .jalr(jalr),
        .wb_src(wb_src), .illegal(illegal));

    assign illegal_out = illegal;

    // ---- register file (lesson 11) -----------------------------------------
    // Note the addresses come straight from fixed instruction bit positions,
    // so the register file is being read WHILE the opcode is still being
    // decoded. Lesson 12 explained why the fields never move; this is the
    // payoff.
    wire [31:0] rd1, rd2;
    wire [31:0] wb_data;

    regfile #(.W(32), .N(32)) u_rf (
        .clk(clk),
        .rs1(rs1_a), .rs2(rs2_a), .rd1(rd1), .rd2(rd2),
        .we(reg_we && !illegal), .rd(rd_a), .wdata(wb_data));

    // ---- ALU (lesson 10) ---------------------------------------------------
    // Three sources for operand A, not two. LUI needs ZERO -- it has no rs1
    // field, so rd1 holds whatever register inst[19:15] happens to name.
    wire [31:0] alu_a = alu_a_zero ? 32'd0 :
                        alu_a_pc   ? pc    : rd1;
    wire [31:0] alu_b = alu_b_imm  ? imm   : rd2;
    wire [31:0] alu_y;
    wire        alu_zero;

    alu #(.W(32)) u_alu (
        .op(alu_op), .a(alu_a), .b(alu_b), .y(alu_y), .zero(alu_zero));

    // ---- branch comparator -------------------------------------------------
    wire taken_cond;
    branch_unit u_br (.a(rd1), .b(rd2), .funct3(mem_op), .taken(taken_cond));
    wire take_branch = branch && taken_cond;

    // ---- data memory -------------------------------------------------------
    // The address is the ALU's result, because the decoder forced an ADD for
    // loads and stores (lesson 12). So rs1 + imm arrives here already summed.
    wire [31:0] addr = alu_y;

    store_align u_sa (
        .addr_lo(addr[1:0]), .funct3(mem_op), .wdata(rd2),
        .mem_wdata(dmem_wdata), .mem_be(dmem_be));

    assign dmem_addr = addr;
    assign dmem_we   = mem_write && !illegal;

    wire [31:0] load_data;
    load_align u_la (
        .addr_lo(addr[1:0]), .funct3(mem_op),
        .mem_rdata(dmem_rdata), .rdata(load_data));

    // ---- writeback ---------------------------------------------------------
    // Three sources. x0 absorbs the write when rd is 0 (lesson 11), which is
    // why `jal x0, label` needs no special case anywhere in this file.
    localparam [1:0] WB_ALU = 2'd0, WB_MEM = 2'd1, WB_PC4 = 2'd2;

    assign wb_data = (wb_src == WB_MEM) ? load_data :
                     (wb_src == WB_PC4) ? pc4 :
                                          alu_y;

    // ---- next PC -----------------------------------------------------------
    // Four possibilities, in priority order. JALR masks bit 0 because the ISA
    // says so -- the target must be even, and the spec defines the low bit as
    // cleared rather than as an error.
    wire [31:0] jalr_target = (rd1 + imm) & ~32'd1;
    wire [31:0] br_target   = pc + imm;

    // ---- signals this design deliberately does not use --------------------
    //
    // Each of these is a real control signal that a different CPU would need,
    // and noticing why this one does not is worth more than silencing the
    // warning:
    //
    //   mem_read   the data memory read is COMBINATIONAL and unconditional --
    //              it is always presenting dmem[addr]. Nothing is gated on
    //              "is this a load"; `wb_src` decides whether the result is
    //              used. A design with a registered or cached memory would
    //              need mem_read to know when to start an access.
    //
    //   alu_zero   branches use the dedicated comparator instead, because the
    //              ALU is busy computing the branch target in the same cycle.
    //              A CPU that computed targets with a separate adder could use
    //              the ALU's zero flag for BEQ and save the comparator.
    //
    //   WB_ALU     named for readability; the writeback mux falls through to
    //              the ALU result rather than comparing against it.
    wire _unused = &{mem_read, alu_zero, WB_ALU, 1'b0};

    always @(posedge clk)
        if (rst)                pc <= 32'd0;
        else if (illegal)       pc <= pc;            // halt, do not execute
        else if (jalr)          pc <= jalr_target;
        else if (jump)          pc <= br_target;     // JAL: pc + imm
        else if (take_branch)   pc <= br_target;
        else                    pc <= pc4;
endmodule
