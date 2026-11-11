# ===========================================================================
#  The Open FPGA Course — top-level Makefile
#
#  Per-lesson work happens inside a lesson folder (`cd 02-combinational &&
#  make sim`). These targets act across the whole course.
# ===========================================================================

# Lessons that currently have code; `make sim-all` is the regression suite.
LESSONS := $(sort $(wildcard [0-9][0-9]-*))
BUILT   := $(foreach d,$(LESSONS),$(if $(wildcard $(d)/Makefile),$(d),))

TOOLS   := toolchain/oss-cad-suite/bin

.PHONY: help sim-all lint-all graph-all clean-all ice docs docs-serve toolchain check pdf pdf-watch
.PHONY: sim bit prog flash lint synth graph wave clean deploy list tasks

help:
	@echo "The Open FPGA Course"
	@echo ""
	@echo "  make sim-all     run every lesson's testbench (must all PASS)"
	@echo "  make lint-all    verilator --lint-only across every lesson"
	@echo "  make graph-all   render every lesson as an SVG schematic"
	@echo "  make ice         regenerate all Icestudio .ice projects from specs"
	@echo "  make tasks       regenerate VS Code's per-lesson task list"
	@echo "  make docs        build the lesson book into docs/book/"
	@echo "  make pdf         build the course book (docs/pdf/book.pdf)"
	@echo "  make docs-serve  serve the book at http://localhost:3000"
	@echo "  make check       verify the toolchain is present and working"
	@echo "  make clean-all   remove build products everywhere"
	@echo ""
	@echo "Work on one lesson, without changing directory:"
	@echo ""
	@echo "  make deploy L=0  build lesson 00 and load it onto the board"
	@echo "  make sim    L=5  simulate lesson 05"
	@echo "  make wave   L=3  open lesson 03's waveform"
	@echo "  make list        show the lesson numbers"
	@echo ""
	@echo "Verbs: sim bit prog flash lint synth graph wave clean deploy"

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

# Regenerate .vscode/tasks.json so each lesson appears by name in VS Code's
# Run Task list. Run after adding a lesson.
tasks:
	@python3 tools/mktasks.py

docs:
	@tools/mkdocs.sh build

# Build the course book: a single PDF with the theory and learning goals of
# every lesson, the ULX3S background, credits, installation and reference.
pdf:
	@tools/mkpdf.sh

# Rebuild the book on every save, for writing it.
pdf-watch:
	@tools/mkpdf.sh --watch

docs-serve:
	@tools/mkdocs.sh serve

check:
	@tools/check.sh

clean-all:
	@for d in $(BUILT); do $(MAKE) -s -C $$d clean; done
	@rm -rf docs/book docs/src/lessons
	@echo "cleaned"

# ===========================================================================
#  Per-lesson verbs, from here, with no navigating.
#
#      make deploy L=0      build 00-blinky and load it onto the board
#      make sim    L=5      simulate 05-fsm
#      make wave   L=3      open 03-sequential's waveform
#
#  L takes a lesson number (0, 3, 05) or a full name (05-fsm). Run `make list`
#  to see them. This exists because remembering which editor tab is focused,
#  or which directory a terminal is in, is friction nobody needs: from the
#  course root, one line does the whole job.
# ===========================================================================

# Resolve L into a directory: "5" and "05" and "05-fsm" all find 05-fsm.
LESSON_DIR = $(firstword $(wildcard $(patsubst %,%*,$(shell printf '%02d' $(L) 2>/dev/null || echo $(L)))) $(wildcard $(L)*))

sim bit prog flash lint synth graph wave clean:
ifeq ($(strip $(L)),)
	@echo ""
	@echo "  '$@' needs a lesson. Which one?"
	@echo ""
	@echo "      make $@ L=0        # 00-blinky"
	@echo "      make $@ L=5        # 05-fsm"
	@echo ""
	@$(MAKE) -s list
	@exit 1
else ifeq ($(strip $(LESSON_DIR)),)
	@echo ""
	@echo "  No lesson matches L=$(L)."
	@echo ""
	@$(MAKE) -s list
	@exit 1
else
	@echo "==> $(LESSON_DIR): make $@"
	@$(MAKE) -C $(LESSON_DIR) $@
endif

# Build and load in one step — the command you will use most.
deploy:
ifeq ($(strip $(LESSON_DIR)),)
	@$(MAKE) -s sim
else
	@echo "==> $(LESSON_DIR): building"
	@$(MAKE) -s -C $(LESSON_DIR) bit
	@echo "==> $(LESSON_DIR): loading onto the board"
	@$(MAKE) -s -C $(LESSON_DIR) prog
endif

list:
	@echo "  Lessons (use the number as L=):"
	@echo ""
	@for d in $(LESSONS); do \
	  n=$${d%%-*}; \
	  if [ -n "$$(ls $$d/*.v 2>/dev/null)" ]; then st="built  "; else st="planned"; fi; \
	  printf '      L=%-3s %-22s %s\n' "$$(echo $$n | sed 's/^0//')" "$$d" "$$st"; \
	done
	@echo ""
