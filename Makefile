# ===========================================================================
#  ULX3S Digital Design Course — top-level Makefile
#
#  Per-lesson work happens inside a lesson folder (`cd 02-combinational &&
#  make sim`). These targets act across the whole course.
# ===========================================================================

# Lessons that currently have code; `make sim-all` is the regression suite.
LESSONS := $(sort $(wildcard [0-9][0-9]-*))
BUILT   := $(foreach d,$(LESSONS),$(if $(wildcard $(d)/Makefile),$(d),))

TOOLS   := toolchain/oss-cad-suite/bin

.PHONY: help sim-all lint-all graph-all clean-all ice docs docs-serve toolchain check
.PHONY: sim bit prog flash lint synth wave clean

help:
	@echo "ULX3S Digital Design Course"
	@echo ""
	@echo "  make sim-all     run every lesson's testbench (must all PASS)"
	@echo "  make lint-all    verilator --lint-only across every lesson"
	@echo "  make graph-all   render every lesson as an SVG schematic"
	@echo "  make ice         regenerate all Icestudio .ice projects from specs"
	@echo "  make docs        build the lesson book into docs/book/"
	@echo "  make docs-serve  serve the book at http://localhost:3000"
	@echo "  make check       verify the toolchain is present and working"
	@echo "  make clean-all   remove build products everywhere"
	@echo ""
	@echo "Lessons with code: $(BUILT)"
	@echo "Then:  cd <lesson> && make sim   (see that lesson's README.md)"

# Rule of the road: the whole course must stay green. Run this before commits.
sim-all:
	@fail=0; \
	for d in $(BUILT); do \
	  printf '\n=== %s ===\n' "$$d"; \
	  if $(MAKE) -s -C $$d sim 2>&1 | tee /tmp/ulx3s-sim.log | grep -qE '^(PASS|.*PASS:)'; then \
	    grep -hE 'PASS' /tmp/ulx3s-sim.log | head -3; \
	  else \
	    echo "FAILED (no PASS in output):"; cat /tmp/ulx3s-sim.log; fail=1; \
	  fi; \
	done; \
	echo ""; \
	if [ $$fail -eq 0 ]; then echo "ALL LESSONS PASS"; else echo "SOME LESSONS FAILED"; exit 1; fi

lint-all:
	@for d in $(BUILT); do printf '\n=== %s ===\n' "$$d"; $(MAKE) -s -C $$d lint || true; done

graph-all:
	@for d in $(BUILT); do printf '\n=== %s ===\n' "$$d"; $(MAKE) -s -C $$d graph; done

# Regenerate every Icestudio project from its JSON spec (see tools/mkice.py).
ice:
	@python3 tools/mkice.py --all

docs:
	@tools/mkdocs.sh build

docs-serve:
	@tools/mkdocs.sh serve

check:
	@tools/check.sh

clean-all:
	@for d in $(BUILT); do $(MAKE) -s -C $$d clean; done
	@rm -rf docs/book docs/src/lessons
	@echo "cleaned"

# ---------------------------------------------------------------------------
#  Per-lesson verbs do not exist at the top level, and the default make error
#  ("No rule to make target `bit'") does not explain why. These catch the
#  mistake and say what to do instead.
#
#  It is an easy mistake to make from an editor: the VS Code tasks run make in
#  the directory of the file you have open, so with a root-level README focused
#  they run here rather than in a lesson.
# ---------------------------------------------------------------------------
sim bit prog flash lint synth wave clean:
	@echo ""
	@echo "  '$@' is a per-LESSON target and there is no lesson selected."
	@echo ""
	@echo "  You are in the course root. Change into a lesson first:"
	@echo ""
	@echo "      cd 00-blinky && make $@"
	@echo ""
	@echo "  In VS Code, these tasks run make in the directory of the file you"
	@echo "  currently have open. Open a .v file inside a lesson, or use the"
	@echo "  'lesson: ...' tasks, which ask which lesson to use."
	@echo ""
	@echo "  Lessons with code: $(BUILT)"
	@echo ""
	@echo "  Course-wide targets: make help"
	@echo ""
	@exit 1
