# Top-level Makefile: delegate to each machine's own Makefile.
#
# Every machine under <Machine>-by-Dar/ owns a Makefile that is the
# authoritative driver for that machine's Basys3 port. This file only forwards
# to it, so a step is invoked as:
#
#     make <step>-<machine>
#
# e.g.  make setup-galaga          make synth-time-pilot
#       make create-prj-galaga     make bitstream-pooyan
#
# All delegation targets, the .PHONY list, and the help matrix are generated
# from the single PORTS list below (token:directory), so the matrix cannot
# drift from the targets. Every machine under the list supports the same full
# step set: setup create-prj clk-wiz patch synth bitstream all clean.
#
# Crazy-Climber-by-Dar is aspirational (documented in the root README but no
# directory yet), so it is deliberately not in PORTS and has no delegation
# targets until the directory exists.

# PORTS := <token>:<directory>  (one entry per present machine dir)
PORTS := \
  bagman:Bagman-FPGA-Dar \
  berzerk:Berzerk-FPGA-by-Dar \
  burger-time:Burger-Time-by-Dar \
  burnin-rubber:Burnin-Rubber-by-Dar \
  computer-space:Computer-Space-by-Dar \
  crazy-kong:Crazy-Kong-by-Dar \
  defender:Defender-by-Dar \
  galaga:Galaga-Midway-by-Dar \
  kick:Kick-Midway-MCR-by-Dar \
  phoenix:Phoenix-by-Dar \
  pooyan:Pooyan-by-Dar \
  popeye:Popeye-by-Dar \
  satans-hollow:Satans-Hollow-by-Dar \
  sky-skipper:Sky-skipper-by-Dar \
  solar-fox:Solar-Fox-by-Dar \
  time-pilot:Time-Pilot-by-Dar \
  traverse-usa:Traverse-USA-by-Dar \
  tron:Tron-by-Dar \
  xevious:Xevious-by-Dar \
  zaxxon:Zaxxon-by-Dar

STEPS := setup create-prj clk-wiz patch synth bitstream all clean

token      = $(word 1,$(subst :, ,$(1)))
directory  = $(word 2,$(subst :, ,$(1)))

# Generate one forwarding target per step per machine.
define DELEGATE
setup-$(1):               ; $(MAKE) -C "$(2)" setup
create-prj-$(1):          ; $(MAKE) -C "$(2)" create_prj
clk-wiz-$(1):             ; $(MAKE) -C "$(2)" clk_wiz
patch-$(1):               ; $(MAKE) -C "$(2)" patch
synth-$(1):               ; $(MAKE) -C "$(2)" synth
bitstream-$(1):           ; $(MAKE) -C "$(2)" bitstream
all-$(1):                 ; $(MAKE) -C "$(2)" all
clean-$(1):               ; $(MAKE) -C "$(2)" clean
endef

$(foreach p,$(PORTS),$(eval $(call DELEGATE,$(call token,$(p)),$(call directory,$(p)))))

MACHINE_TARGETS := $(foreach s,$(STEPS),$(foreach p,$(PORTS),$(s)-$(call token,$(p))))

# Bare `make` prints help instead of running a build.
.DEFAULT_GOAL := help

.PHONY: help clean bitstream $(MACHINE_TARGETS)

# Clean every machine (delegated). Leaves the dloads/ source-archive cache in
# place so a later `make setup` does not re-download.
clean:
	@for p in $(PORTS); do \
	  d="$${p#*:}"; \
	  [ -d "$$d" ] || { echo "skipping missing directory $$d"; continue; }; \
	  $(MAKE) -C "$$d" clean || exit 1; \
	done
	@echo "All machines cleaned."

# Build every machine's bitstream, skipping machines that already have
# <machine>/vhdl_*/basys3/*.runs/impl_1/*.bit, so re-running a partial sweep
# only builds what's missing. The two globs cover the standard layout depth
# and Pooyan's nested basys3/pooyan_basys3/ project. Each machine's `bitstream`
# target stages setup -> create_prj -> clk_wiz -> patch -> synth first. Runs
# Vivado (per .opencode/rules.md, run only on explicit request); expect a long
# run. Stale detection (rebuild when .bit predates sources) is not in scope.
bitstream:
	@for p in $(PORTS); do \
	  d="$${p#*:}"; \
	  t="$${p%%:*}"; \
	  [ -d "$$d" ] || { echo "skipping missing directory $$d"; continue; }; \
	  bits="$$(ls -1 "$$d"/vhdl_*/*/*.runs/impl_1/*.bit "$$d"/vhdl_*/*/*/*.runs/impl_1/*.bit 2>/dev/null || true)"; \
	  if [ -n "$$bits" ]; then \
	    echo "==> $$t: bitstream already built, skipping"; \
	    continue; \
	  fi; \
	  echo "==> building bitstream: $$d"; \
	  $(MAKE) -C "$$d" bitstream || exit 1; \
	done
	@echo "Bitstream sweep complete."

help:
	@echo "Top-level port driver. Each step delegates to the machine's own Makefile."
	@echo "Usage: make <step>-<machine>"
	@echo
	@echo "Machines and their steps:"
	@for p in $(PORTS); do \
	  t="$${p%%:*}"; \
	  printf "  %-16s : setup create-prj clk-wiz patch synth bitstream all clean\n" "$$t"; \
	done
	@echo
	@echo "Cleaning: make clean delegates 'clean' to every machine (keeps the dloads/ cache)."
	@echo "Bitstream: make bitstream builds machines lacking an impl_1 .bit,"
	@echo "           skipping already-built ones (Vivado, long-running; per"
	@echo "           .opencode/rules.md run only on explicit request)."
	@echo
	@echo "Examples:"
	@echo "  make setup-galaga      make synth-time-pilot      make bitstream-pooyan"