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
