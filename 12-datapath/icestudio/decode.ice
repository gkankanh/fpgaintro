{
  "version": "1.2",
  "package": {
    "name": "decode",
    "version": "1.0",
    "description": "Lesson 12 - the RV32I decoder: switch between eight real instructions and watch the control lines.",
    "author": "The Open FPGA Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "a93b16b7-2c8c-505a-b004-478ab38f42c4",
          "type": "basic.input",
          "data": {
            "name": "instruction select (sw3..sw0)",
            "pins": [
              {
                "index": "3",
                "name": "sw_3",
                "value": "E7"
              },
              {
                "index": "2",
                "name": "sw_2",
                "value": "D7"
              },
              {
                "index": "1",
                "name": "sw_1",
                "value": "D8"
              },
              {
                "index": "0",
                "name": "sw_0",
                "value": "E8"
              }
            ],
            "virtual": false,
            "range": "[3:0]"
          },
          "position": {
            "x": -240,
            "y": 48
          }
        },
        {
          "id": "4f5e3e44-aced-5bde-aa3b-701165729151",
          "type": "basic.output",
          "data": {
            "name": "illegal jump branch sw ld we imm pc",
            "pins": [
              {
                "index": "7",
                "name": "led_7",
                "value": "H3"
              },
              {
                "index": "6",
                "name": "led_6",
                "value": "E1"
              },
              {
                "index": "5",
                "name": "led_5",
                "value": "E2"
              },
              {
                "index": "4",
                "name": "led_4",
                "value": "D1"
              },
              {
                "index": "3",
                "name": "led_3",
                "value": "D2"
              },
              {
                "index": "2",
                "name": "led_2",
                "value": "C1"
              },
              {
                "index": "1",
                "name": "led_1",
                "value": "C2"
              },
              {
                "index": "0",
                "name": "led_0",
                "value": "B2"
              }
            ],
            "virtual": false,
            "range": "[7:0]"
          },
          "position": {
            "x": 816,
            "y": 48
          }
        },
        {
          "id": "6c9ab3aa-23f9-5a0e-96df-4cb6f4776a31",
          "type": "basic.code",
          "data": {
            "code": "// ---------------------------------------------------------------\n// Added by tools/mkice.py, not present in the lesson's .v:\n// Icestudio declares a code block's outputs as wires, and the\n// board has fewer pins than this module has port bits. See\n// icestudio/README.md. The module's own text below is verbatim.\n// ---------------------------------------------------------------\nwire [31:0] inst = sw == 4'd0 ? 32'h00500093 : sw == 4'd1 ? 32'h003100b3 : sw == 4'd2 ? 32'h403100b3 : sw == 4'd3 ? 32'h00012083 : sw == 4'd4 ? 32'h00112023 : sw == 4'd5 ? 32'hfe2086e3 : sw == 4'd6 ? 32'hfe9ff0ef : sw == 4'd7 ? 32'h123450b7 : 32'hffffffff;\nwire [4:0] rs1;\nwire [4:0] rs2;\nwire [4:0] rd;\nwire reg_we;\nwire [3:0] alu_op;\nwire alu_a_pc;\nwire alu_a_zero;\nwire alu_b_imm;\nwire mem_read;\nwire mem_write;\nwire [2:0] mem_op;\nwire branch;\nwire jump;\nwire jalr;\nwire [1:0] wb_src;\nwire illegal;\n\nlocalparam [6:0] OP_LOAD   = 7'b0000011,\n                 OP_IMM    = 7'b0010011,\n                 OP_AUIPC  = 7'b0010111,\n                 OP_STORE  = 7'b0100011,\n                 OP_REG    = 7'b0110011,\n                 OP_LUI    = 7'b0110111,\n                 OP_BRANCH = 7'b1100011,\n                 OP_JALR   = 7'b1100111,\n                 OP_JAL    = 7'b1101111;\n\nlocalparam [1:0] WB_ALU = 2'd0, WB_MEM = 2'd1, WB_PC4 = 2'd2;\n\nwire [6:0] opcode = inst[6:0];\nwire [2:0] funct3 = inst[14:12];\nwire [6:0] funct7 = inst[31:25];\n\n// Fields at fixed positions, extracted unconditionally.\nassign rs1 = inst[19:15];\nassign rs2 = inst[24:20];\nassign rd  = inst[11:7];\n\nassign mem_op = funct3;\n\n// ---- which instruction class is this? ---------------------------------\nwire is_reg    = (opcode == OP_REG);\nwire is_imm    = (opcode == OP_IMM);\nwire is_load   = (opcode == OP_LOAD);\nwire is_store  = (opcode == OP_STORE);\nwire is_branch = (opcode == OP_BRANCH);\nwire is_jal    = (opcode == OP_JAL);\nwire is_jalr   = (opcode == OP_JALR);\nwire is_lui    = (opcode == OP_LUI);\nwire is_auipc  = (opcode == OP_AUIPC);\n\n// ---- the ALU operation ------------------------------------------------\n//\n// Lesson 10's ALU takes {instr[30], funct3}, which falls straight out of\n// the instruction for R-type. For I-type it very nearly does, and the\n// exception is a REAL BUG that is easy to ship:\n//\n//   addi x1, x2, -1\n//\n// has imm = 0xFFF, so inst[31:20] is all ones and inst[30] is 1. Pass\n// {inst[30], funct3} = {1, 000} to the ALU and it performs SUB instead of\n// ADD -- so `addi` with any negative immediate silently subtracts.\n//\n// inst[30] is only meaningful for OP-IMM when funct3 == 101, i.e.\n// SRLI versus SRAI. Everywhere else in OP-IMM it is part of the\n// immediate and must be forced to zero.\nwire use_bit30 = is_reg || (is_imm && funct3 == 3'b101);\nwire alu_bit30 = use_bit30 ? inst[30] : 1'b0;\n\n// Loads, stores, jumps, AUIPC and LUI all need an ADDITION regardless of\n// what funct3 says -- for those instructions funct3 means something else\n// entirely (a width, or which comparison), so it must not reach the ALU.\n//\n// LUI reuses ADD with operand A forced to ZERO, which is why RV32I needs\n// no \"pass-through\" ALU operation.\nwire needs_add = is_load || is_store || is_jal || is_jalr\n                         || is_auipc || is_lui;\n\n// ONE assignment to the output. An earlier version assigned alu_op from\n// {alu_bit30, funct3} and then computed a separate `alu_op_final` that\n// was never connected to anything -- so the needs_add override silently\n// did nothing and every load would have asked the ALU for whatever funct3\n// happened to mean. `make lint` caught the dangling wire; it is a good\n// argument for keeping exactly one assignment per output.\nassign alu_op = needs_add ? 4'b0000 : {alu_bit30, funct3};\n\n// ---- operand sources --------------------------------------------------\n//\n// LUI AND OPERAND A. An earlier version of this file carried a comment\n// claiming \"rs1 is x0 by convention for LUI\" and relied on it. That is\n// FALSE: LUI has no rs1 field at all -- inst[19:15] is part of its 20-bit\n// immediate. So the ALU was adding the immediate to whatever register\n// those five bits happened to name, and since the register file starts\n// undefined, lesson 13's CPU stored X and the X's propagated through\n// every value built with `li` of a large constant.\n//\n// Found by running real software, which is exactly what lesson 13 is for:\n// the decoder's own testbench checked that LUI asks the ALU for ADD, and\n// it does. It never checked where operand A came from.\n//\n// JAL and AUIPC have the same field overlap but are already safe, because\n// they take operand A from the PC.\nassign alu_a_pc   = is_auipc || is_jal;\nassign alu_a_zero = is_lui;\nassign alu_b_imm  = !is_reg && !is_branch;\n\n// ---- memory -----------------------------------------------------------\nassign mem_read  = is_load;\nassign mem_write = is_store;\n\n// ---- control flow -----------------------------------------------------\nassign branch = is_branch;\nassign jump   = is_jal || is_jalr;\nassign jalr   = is_jalr;\n\n// ---- writeback --------------------------------------------------------\n// Stores and branches write no register. x0 absorbs a write anyway\n// (lesson 11), so `jal x0, L` needs no special case here.\nassign reg_we = is_reg || is_imm || is_load || is_lui || is_auipc\n                       || is_jal || is_jalr;\n\nassign wb_src = is_load            ? WB_MEM :\n                (is_jal || is_jalr) ? WB_PC4 :\n                                      WB_ALU;\n\n// ---- illegal instruction ----------------------------------------------\n//\n// Everything not recognised above. A real CPU must trap rather than\n// execute something arbitrary, and lesson 17 wires this to the trap\n// mechanism. Having the signal from the start costs one wire and means\n// the CPU is never silently executing nonsense.\n//\n// The funct7 checks catch malformed R-type: only 0000000 and 0100000 are\n// legal, and 0100000 only for SUB and SRA.\nwire bad_funct7 = is_reg &&\n                  !((funct7 == 7'b0000000) ||\n                    (funct7 == 7'b0100000 &&\n                     (funct3 == 3'b000 || funct3 == 3'b101)));\n\n// Branches have no funct3 == 010 or 011.\nwire bad_branch = is_branch && (funct3 == 3'b010 || funct3 == 3'b011);\n\n// Loads have no funct3 == 011, 110 or 111; stores only 000, 001, 010.\nwire bad_load   = is_load &&\n                  (funct3 == 3'b011 || funct3 == 3'b110 || funct3 == 3'b111);\nwire bad_store  = is_store && (funct3 != 3'b000 && funct3 != 3'b001\n                                                && funct3 != 3'b010);\n// JALR's funct3 must be 000.\nwire bad_jalr   = is_jalr && (funct3 != 3'b000);\n\nwire known = is_reg | is_imm | is_load | is_store | is_branch\n           | is_jal | is_jalr | is_lui | is_auipc;\n\nassign illegal = !known | bad_funct7 | bad_branch\n                        | bad_load   | bad_store | bad_jalr;\n\n// ---- added by tools/mkice.py: port aliases and probes ----\nassign ctrl = {illegal, jump, branch, mem_write, mem_read, reg_we, alu_b_imm, alu_a_pc};\n",
            "params": [],
            "ports": {
              "in": [
                {
                  "name": "sw",
                  "range": "[3:0]",
                  "size": 4
                }
              ],
              "out": [
                {
                  "name": "ctrl",
                  "range": "[7:0]",
                  "size": 8
                }
              ]
            }
          },
          "position": {
            "x": 384,
            "y": 48
          }
        },
        {
          "id": "1f03ec4a-7aa9-5018-8789-150978aba0fb",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 12 - the decoder, one instruction at a time\n\nThe slide switches select a real instruction, assembled by `tools/rvasm.py`, and the LEDs show eight of the control lines it produces. Nothing here is clocked: a decoder is a function of the instruction word and nothing else.\n\n| sw3..sw0 | instruction | LEDs that light |\n|---|---|---|\n| 0000 | `addi x1, x0, 5` | we, imm |\n| 0001 | `add x1, x2, x3` | we |\n| 0010 | `sub x1, x2, x3` | we |\n| 0011 | `lw x1, 0(x2)` | ld, we, imm |\n| 0100 | `sw x1, 0(x2)` | sw, imm |\n| 0101 | `beq x1, x2, -20` | branch |\n| 0110 | `jal x1, -24` | jump, we, imm, pc |\n| 0111 | `lui x1, 0x12345` | we, imm |\n| 1xxx | `0xffffffff` | **illegal**, imm |\n\nThe LEDs, left to right, are `illegal`, `jump`, `branch`, `mem_write`, `mem_read`, `reg_we`, `alu_b_imm`, `alu_a_pc`.\n\n### What to notice\n\n`add` and `sub` light exactly the same lamps - verified in simulation, not by reading the source. The difference between them is not a control line at all - it is `inst[30]`, which rides into `alu_op` and changes what the ALU does, not what the datapath does. That is the decoder's whole design: say as little as possible, as early as possible.\n\nSwitch to any `1xxx` and `illegal` lights. Look at which lamps go out with it: `reg_we`, `mem_write`, `mem_read`, `branch` and `jump` - every line that **commits** something. An instruction the decoder does not recognise must not write a register, store a byte or move the PC, and that is exactly what you see.\n\n`alu_b_imm` stays lit, which is worth understanding rather than worrying about: with nothing committing, whether operand B comes from the immediate or from rs2 changes no state at all. It is a don't-care, and the decoder spends no logic forcing don't-cares to zero.\n\n### Why `inst` is not on pins\n\nThe decoder takes 32 bits in and produces 27 bits of control out. The board has 4 switches, 7 buttons and 8 LEDs, so the full interface is impossible by a factor of eight. The switches pick from a table instead, and the other 19 outputs are declared inside the block and left unconnected. This is the point at which schematic entry stops being the better view - which is why lessons 10 and up are editor-first, and why the lesson's own testbench drives all 32 bits: `cd 12-datapath && make sim`.",
            "readonly": true
          },
          "position": {
            "x": 48,
            "y": 232
          }
        }
      ],
      "wires": [
        {
          "source": {
            "block": "a93b16b7-2c8c-505a-b004-478ab38f42c4",
            "port": "out"
          },
          "target": {
            "block": "6c9ab3aa-23f9-5a0e-96df-4cb6f4776a31",
            "port": "sw"
          },
          "size": 4
        },
        {
          "source": {
            "block": "6c9ab3aa-23f9-5a0e-96df-4cb6f4776a31",
            "port": "ctrl"
          },
          "target": {
            "block": "4f5e3e44-aced-5bde-aa3b-701165729151",
            "port": "in"
          },
          "size": 8
        }
      ]
    }
  },
  "dependencies": {}
}
