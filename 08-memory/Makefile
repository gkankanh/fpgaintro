# Lesson 08 — memories. See README.md.
#
# font.hex is read by $readmemh at elaboration time, so it is a source file,
# not a build product. Change it and you must resynthesise.
TOP  = mem_top
SRCS = ram.v rom.v framebuffer.v mem_test.v ../common/rtl/debounce.v mem_top.v
TB   = tb_mem
VCD  = mem.vcd
include ../common/lesson.mk
