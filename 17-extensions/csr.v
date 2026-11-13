`timescale 1ns/1ps
// ===========================================================================
//  Lesson 17 — the control and status registers, and the trap state.
//
//  A CSR is an architecturally visible register that is not one of the 32
//  general-purpose ones. RISC-V gives them a 12-bit address space of their
//  own, reached only by the CSR instructions, and that separation is the
//  point: x1..x31 belong to the program, and these belong to the MACHINE.
//
//  This file holds the smallest set that makes traps and interrupts work.
//  There are hundreds in the specification; a core needs about nine.
//
//    mstatus  0x300  MIE  (bit 3)  are interrupts enabled right now?
//                    MPIE (bit 7)  were they enabled before the trap?
//                    MPP  (12:11)  which mode we came from -- always 11 here
//    misa     0x301  read-only: which extensions exist. "RV32IM".
//    mie      0x304  MTIE (bit 7): is the TIMER interrupt allowed?
//    mtvec    0x305  where to jump when a trap happens
//    mscratch 0x340  a word the handler may use. See below -- it is not junk.
//    mepc     0x341  the PC to resume at
//    mcause   0x342  why we trapped; bit 31 set means "interrupt"
//    mtval    0x343  extra detail: the bad address, or the bad instruction
//    mip      0x344  read-only: MTIP (bit 7), the timer is asking
//    mcycle   0xB00  clocks since reset
//    minstret 0xB02  instructions retired since reset -- so the machine can
//                    compute its own CPI, which lesson 16 had to do in a
//                    simulator
//    mhartid  0xF14  which hart this is. Zero. There is only one.
//
//  WHY mscratch EXISTS, which is the most interesting register here. A trap
//  handler needs a register to work with before it can save anything -- but
//  every register already belongs to the interrupted program, so using one
//  destroys it. mscratch is the way out: `csrrw sp, mscratch, sp` atomically
//  swaps the stack pointer with a saved kernel stack pointer, giving the
//  handler one usable register without having lost anything. An entire
//  operating system's entry sequence turns on that single instruction.
//
//  WHY THE WRITE ORDER IN THIS FILE MATTERS. A CSR instruction commits in EX
//  while a trap is taken in ID, so both can land on the same clock edge --
//  and the CSR instruction is the EARLIER one in program order. Its write is
//  therefore applied first and the trap's updates second, which is what the
//  sequence of non-blocking assignments below does. Swap the two blocks and
//  an interrupt arriving next to a `csrw mstatus` would sometimes re-enable
//  interrupts inside the handler.
// ===========================================================================
module csr (
    input  wire        clk,
    input  wire        rst,

    // ---- the CSR instruction, executing in EX ----------------------------
    input  wire        en,            // a valid CSR instruction is in EX
    input  wire [11:0] addr,
    input  wire [1:0]  op,            // 0 = write, 1 = set, 2 = clear
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,

    // ---- trap entry, decided in ID ---------------------------------------
    input  wire        trap,
    input  wire [31:0] trap_pc,
    input  wire [31:0] trap_cause,
    input  wire [31:0] trap_val,
    output wire [31:0] mtvec_out,

    // ---- MRET ------------------------------------------------------------
    input  wire        mret,
    output wire [31:0] mepc_out,

    // ---- the outside world -----------------------------------------------
    input  wire        mtip,          // the timer says it is time
    output wire        irq_ready,     // enabled AND pending: take it

    input  wire        retire         // an instruction completed this cycle
);
    localparam [11:0] MSTATUS = 12'h300, MISA   = 12'h301, MIE_A  = 12'h304,
                      MTVEC   = 12'h305, MSCR   = 12'h340, MEPC   = 12'h341,
                      MCAUSE  = 12'h342, MTVAL  = 12'h343, MIP_A  = 12'h344,
                      MCYCLE  = 12'hB00, MINSTR = 12'hB02, MHARTID= 12'hF14;

    reg        mstatus_mie  = 0;
    reg        mstatus_mpie = 0;
    reg [31:0] mtvec    = 0;
    reg        mie_mtie = 0;
    reg [31:0] mscratch = 0;
    reg [31:0] mepc     = 0;
    reg [31:0] mcause   = 0;
    reg [31:0] mtval    = 0;
    reg [31:0] mcycle   = 0;
    reg [31:0] minstret = 0;

    assign mtvec_out = mtvec;
    assign mepc_out  = mepc;

    // An interrupt is taken only when it is BOTH pending and enabled, and
    // "enabled" is two bits in two registers: the global MIE and the
    // per-source MTIE. Two levels, because an operating system wants to mask
    // one device without masking all of them.
    assign irq_ready = mstatus_mie && mie_mtie && mtip;

    // RV32IM: MXL = 1 (32-bit) in the top two bits, plus one bit per
    // extension letter -- 'I' is bit 8, 'M' is bit 12.
    localparam [31:0] MISA_VAL = 32'b01 << 30 | (32'd1 << 8) | (32'd1 << 12);

    // ---- read --------------------------------------------------------------
    // Combinational: the CSR instruction reads and writes in the same cycle,
    // and reads the OLD value, which is what CSRRW's definition requires.
    always @(*)
        case (addr)
            MSTATUS: rdata = {19'd0, 2'b11, 3'd0, mstatus_mpie,
                              3'd0, mstatus_mie, 3'd0};
            MISA:    rdata = MISA_VAL;
            MIE_A:   rdata = {24'd0, mie_mtie, 7'd0};
            MTVEC:   rdata = mtvec;
            MSCR:    rdata = mscratch;
            MEPC:    rdata = mepc;
            MCAUSE:  rdata = mcause;
            MTVAL:   rdata = mtval;
            MIP_A:   rdata = {24'd0, mtip, 7'd0};
            MCYCLE:  rdata = mcycle;
            MINSTR:  rdata = minstret;
            MHARTID: rdata = 32'd0;
            // An unimplemented CSR reads as zero here. The specification says
            // it should raise an illegal-instruction exception, and a core
            // that means to run an operating system must do that -- see the
            // README for what this machine does not claim.
            default: rdata = 32'd0;
        endcase

    // ---- the value a write would store -------------------------------------
    wire [31:0] next = (op == 2'd0) ? wdata :
                       (op == 2'd1) ? (rdata | wdata) :
                                      (rdata & ~wdata);

    // CSRRS/CSRRC with an all-zero operand must NOT write: that is how
    // `csrr rd, csr` is spelled, and on a register with write side effects
    // the difference is everything.
    wire write = en && ((op == 2'd0) || (wdata != 32'd0));

    // ---- state -------------------------------------------------------------
    always @(posedge clk) begin
        // Counters first, so an explicit write below overrides the tick.
        mcycle <= mcycle + 32'd1;
        if (retire) minstret <= minstret + 32'd1;

        // 1. the CSR instruction in EX -- the earlier instruction
        if (write)
            case (addr)
                MSTATUS: begin
                    mstatus_mie  <= next[3];
                    mstatus_mpie <= next[7];
                end
                MIE_A:   mie_mtie <= next[7];
                // mtvec's low two bits select the mode: 0 = direct, 1 =
                // vectored. This core implements direct only, so they are
                // forced to zero rather than quietly ignored -- a handler
                // that reads back a mode it did not get is a bug nobody finds.
                MTVEC:   mtvec    <= {next[31:2], 2'b00};
                MSCR:    mscratch <= next;
                MEPC:    mepc     <= {next[31:1], 1'b0};   // always even
                MCAUSE:  mcause   <= next;
                MTVAL:   mtval    <= next;
                MCYCLE:  mcycle   <= next;
                MINSTR:  minstret <= next;
                default: ;                                 // read-only or absent
            endcase

        // 2. the trap -- which happens after it, in program order
        if (trap) begin
            mepc         <= trap_pc;
            mcause       <= trap_cause;
            mtval        <= trap_val;
            mstatus_mpie <= mstatus_mie;   // remember whether they were on
            mstatus_mie  <= 1'b0;          // and turn them off
        end else if (mret) begin
            mstatus_mie  <= mstatus_mpie;  // put them back as they were
            mstatus_mpie <= 1'b1;
        end

        if (rst) begin
            mstatus_mie  <= 0;
            mstatus_mpie <= 0;
            mtvec        <= 0;
            mie_mtie     <= 0;
            mcause       <= 0;
            mtval        <= 0;
            mepc         <= 0;
            mcycle       <= 0;
            minstret     <= 0;
        end
    end
endmodule
