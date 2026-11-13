`timescale 1ns/1ps
// ===========================================================================
//  Lesson 15 — the address decoder: the whole memory map, in one small file.
//
//  Lesson 13's memories ignored the high address bits entirely, so 0x0000_0100
//  and 0xDEAD_0100 hit the same word. The memory ALIASED across the whole
//  32-bit space, and every address was therefore "valid". Nothing could ever
//  be wrong, which sounds convenient and means no mistake is ever reported.
//
//  A decoder looks at the high bits and decides WHICH DEVICE an address
//  belongs to. That is the memory map, and this file is the whole of it:
//
//      0x0000_0000 .. 0x0000_0FFF   memory   (MEM_BYTES of it)
//      0x8000_0000 .. 0x8000_00FF   I/O      (the peripheral registers)
//      everything else              nothing
//
//  WHY THE I/O WINDOW IS AT THE TOP BIT. Peripherals are placed where one
//  comparison can find them: addr[31] alone separates I/O from memory, so a
//  select line costs a single LUT input rather than a 32-bit comparator. Real
//  memory maps are laid out with exactly this in mind -- the reason a
//  peripheral block sits at 0x4000_0000 or 0xE000_0000 and never at
//  0x1234_5678 is that this decoder is in series with every memory access the
//  machine will ever make.
//
//  ---------------------------------------------------------------------
//  WHY `fault` IS QUALIFIED BY `access`, WHICH IS THE INTERESTING PART
//
//  A decoder's other job is to report an address that belongs to nothing. For
//  STORES this works: `we` is asserted only by a real store instruction, so a
//  store to 0x0DD0_0000 is unambiguously a mistake and `fault` says so.
//
//  For LOADS it cannot work, and the reason is a decision made two lessons
//  ago. The lesson 13 core reads its data memory UNCONDITIONALLY -- every
//  instruction puts its ALU result on the address bus, load or not, and the
//  writeback mux decides whether the returned word is used. Its `mem_read`
//  signal exists but is not brought out of the module; it is sitting in that
//  core's list of deliberately unused signals.
//
//  So `addi t0, zero, 0x7FF` would present 0x7FF on the data address bus, and
//  a decoder that faulted on unmapped READS would fault on an add. The
//  address bus carries garbage most cycles and there is no way, from outside
//  the core, to tell the garbage from an access.
//
//  The honest fix is one more output wire on the CPU. Lesson 16's core brings
//  `mem_read` out -- a pipeline has to know which stage is accessing memory
//  anyway -- and drives this same `access` pin with "write OR read", which is
//  what it always meant. Lesson 17 then gives the fault somewhere to be
//  reported TO. Here, a load from nowhere quietly reads whatever the aliased
//  word holds, and the README says so.
//
//  The port is therefore called `access` and not `we`: it is named for the
//  question the decoder is asking, not for the only answer this lesson's CPU
//  can give.
// ===========================================================================
module busdec #(
    parameter MEM_BYTES = 4096           // the memory array's size, in bytes
)(
    input  wire [31:0] addr,
    input  wire        access,           // this cycle is a real access.
                                         // Lesson 15 can only ever say
                                         // "a store"; lesson 16 says
                                         // "a store or a load".

    output wire        sel_mem,          // address is in the memory array
    output wire        sel_io,           // address is a peripheral register
    output wire        fault             // an access to an address that is neither
);
    // A real comparison, and the thing that makes a wild pointer reportable
    // instead of silently aliasing onto something innocent.
    wire in_mem = (addr < MEM_BYTES);
    wire in_io  = (addr[31:8] == 24'h80_0000);

    assign sel_mem = in_mem;
    assign sel_io  = in_io;
    assign fault   = access && !in_mem && !in_io;
endmodule
