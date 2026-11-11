# Lesson 14 — formal verification. See README.md.
#
# This lesson has no design of its own: it proves the ALU from lesson 10 and
# the register file from lesson 11. So the usual `make sim` runs the PROOFS,
# which is what puts formal verification into the course-wide regression
# suite alongside every other lesson.

.PHONY: sim formal formal-all formal-broken formal-vacuous wave lint synth bit prog graph clean help

sim:
	@./run-proofs.sh

# Everything, including the register file (about a minute).
formal formal-all:
	@./run-proofs.sh --all

# The two demonstrations, run on their own so the output can be read.
formal-broken:
	@PATH=../toolchain/oss-cad-suite/bin:$$PATH sby -f broken.sby

formal-vacuous:
	@echo "--- the proof passes ---"
	@PATH=../toolchain/oss-cad-suite/bin:$$PATH sby -f vacuous.sby prove
	@echo ""
	@echo "--- and the cover shows it was worthless ---"
	@PATH=../toolchain/oss-cad-suite/bin:$$PATH sby -f vacuous.sby cover

# Open the counterexample the solver produced for the broken ALU.
wave:
	@PATH=../toolchain/oss-cad-suite/bin:$$PATH gtkwave broken/engine_0/trace.vcd &

# There is nothing here to lint, synthesise or program: the designs under
# proof belong to lessons 10 and 11, where they are already checked.
lint synth bit prog graph:
	@echo "lesson 14 proves lessons 10 and 11; run '$@' there instead"

clean:
	rm -rf alu_prove alu_cover regfile_prove regfile_cover broken \
	       vacuous_prove vacuous_cover
