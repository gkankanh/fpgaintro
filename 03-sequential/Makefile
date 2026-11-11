# Lesson 03 — sequential logic. See README.md.
#
# debounce.v lived here while this lesson was about it. Lesson 05 needed it
# too, so it moved to common/rtl/ — see that directory's README for the rule.
# There is exactly one copy, and this lesson still builds and runs.
TOP  = seq_top
SRCS = dff.v ../common/rtl/debounce.v seq_top.v
TB   = tb_seq
VCD  = seq.vcd
include ../common/lesson.mk
