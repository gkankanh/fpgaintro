# ===========================================================================
#  Lesson 13 — a program that exercises RV32I and records what it found.
#
#  Every result is STORED TO MEMORY at a known address, and the testbench
#  checks memory rather than peeking at the register file. That matters: it
#  tests the CPU through the interface software actually uses, so a CPU that
#  computes correctly but stores wrongly still fails.
#
#  Assemble with:  tools/rvasm.py test.s -o test.hex
# ===========================================================================

_start:
        # ---- arithmetic -------------------------------------------------
        li      t0, 10
        li      t1, 3
        add     t2, t0, t1              # 13
        sw      t2, 0x100(zero)
        sub     t2, t0, t1              # 7
        sw      t2, 0x104(zero)

        # ---- THE LESSON 12 TRAP: addi with a negative immediate ---------
        # inst[30] is 1 here. A decoder that passes it to the ALU computes
        # SUB and stores 11 instead of 9.
        addi    t2, t0, -1              # 9
        sw      t2, 0x108(zero)
        addi    t2, zero, -2048         # -2048, the most negative I-immediate
        sw      t2, 0x10c(zero)

        # ---- logic ------------------------------------------------------
        li      t0, 0xF0F0
        li      t1, 0x0FF0
        and     t2, t0, t1              # 0x00F0
        sw      t2, 0x110(zero)
        or      t2, t0, t1              # 0xFFF0
        sw      t2, 0x114(zero)
        xor     t2, t0, t1              # 0xFF00
        sw      t2, 0x118(zero)

        # ---- shifts, including the arithmetic/logical distinction -------
        li      t0, -16
        srai    t2, t0, 2               # -4
        sw      t2, 0x11c(zero)
        srli    t2, t0, 28              # 0xF  (logical: no sign extension)
        sw      t2, 0x120(zero)
        slli    t2, t1, 4               # 0xFF00
        sw      t2, 0x124(zero)

        # ---- signed versus unsigned comparison --------------------------
        li      t0, -1
        li      t1, 1
        slt     t2, t0, t1              # 1: signed, -1 < 1
        sw      t2, 0x128(zero)
        sltu    t2, t0, t1              # 0: unsigned, 0xFFFFFFFF > 1
        sw      t2, 0x12c(zero)

        # ---- byte and halfword memory access ----------------------------
        li      t0, 0x12345678
        sw      t0, 0x200(zero)
        lb      t2, 0x200(zero)         # 0x78
        sw      t2, 0x130(zero)
        lbu     t2, 0x203(zero)         # 0x12
        sw      t2, 0x134(zero)
        lh      t2, 0x202(zero)         # 0x1234
        sw      t2, 0x138(zero)

        # A byte store must change ONE byte and leave the rest alone.
        li      t1, 0xFF
        sb      t1, 0x201(zero)
        lw      t2, 0x200(zero)         # 0x1234FF78
        sw      t2, 0x13c(zero)

        # Sign extension on load: the whole reason LB and LBU both exist.
        li      t0, 0x80
        sb      t0, 0x204(zero)
        lb      t2, 0x204(zero)         # 0xFFFFFF80
        sw      t2, 0x140(zero)
        lbu     t2, 0x204(zero)         # 0x00000080
        sw      t2, 0x144(zero)

        # ---- a loop with a backward branch ------------------------------
        li      t0, 0                   # accumulator
        li      t1, 1                   # counter
        li      t3, 11                  # limit
sumloop:
        add     t0, t0, t1
        addi    t1, t1, 1
        blt     t1, t3, sumloop
        sw      t0, 0x148(zero)         # 1+2+...+10 = 55

        # ---- call and return --------------------------------------------
        jal     ra, subr
        sw      a0, 0x14c(zero)         # 99

        # ---- branches that must NOT be taken ----------------------------
        li      t0, 5
        li      t1, 5
        bne     t0, t1, bad
        bltu    t0, t1, bad
        beq     t0, t1, ok1
        j       bad
ok1:
        li      t2, 1
        sw      t2, 0x150(zero)

        # ---- lui, and auipc relative to a known PC ----------------------
        lui     t2, 0xABCDE
        sw      t2, 0x154(zero)         # 0xABCDE000

        # ---- jalr through a register ------------------------------------
        la      t0, target
        jalr    ra, 0(t0)
        sw      a0, 0x158(zero)         # 0x5A5A
        j       done

target:
        li      a0, 0x5A5A
        ret

subr:
        li      a0, 99
        ret

bad:
        li      t2, 0xBAD
        sw      t2, 0x1F8(zero)
        j       halt

done:
        li      t2, 1
        sw      t2, 0x1FC(zero)         # the "finished cleanly" flag
halt:
        j       halt
