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
# Available steps vary per machine (create_prj is not universal — Pooyan lacks
# it). Use `make help` to list what each machine supports.

GALAGA      := Galaga-Midway-by-Dar
POOYAN      := Pooyan-by-Dar
TIME_PILOT  := Time-Pilot-by-Dar
BAGMAN      := Bagman-FPGA-Dar
BERZERK     := Berzerk-FPGA-by-Dar
TRON        := Tron-by-Dar
KICK        := Kick-Midway-MCR-by-Dar
BURGER_TIME := Burger-Time-by-Dar
DEFENDER    := Defender-by-Dar
TRAVERSE_USA := Traverse-USA-by-Dar
CRAZY_KONG   := Crazy-Kong-by-Dar
CRAZY_CLIMBER := Crazy-Climber-by-Dar
SKY_SKIPPER   := Sky-skipper-by-Dar
SATANS_HOLLOW := Satans-Hollow-by-Dar

# Bare `make` prints help instead of running a build.
.DEFAULT_GOAL := help

# ---- Galaga ----
setup-galaga:
	$(MAKE) -C "$(GALAGA)" setup

create-prj-galaga:
	$(MAKE) -C "$(GALAGA)" create_prj

clk-wiz-galaga:
	$(MAKE) -C "$(GALAGA)" clk_wiz

patch-galaga:
	$(MAKE) -C "$(GALAGA)" patch

synth-galaga:
	$(MAKE) -C "$(GALAGA)" synth

bitstream-galaga:
	$(MAKE) -C "$(GALAGA)" bitstream

all-galaga:
	$(MAKE) -C "$(GALAGA)" all

clean-galaga:
	$(MAKE) -C "$(GALAGA)" clean

# ---- Pooyan ----
setup-pooyan:
	$(MAKE) -C "$(POOYAN)" setup

clk-wiz-pooyan:
	$(MAKE) -C "$(POOYAN)" clk_wiz

patch-pooyan:
	$(MAKE) -C "$(POOYAN)" patch

synth-pooyan:
	$(MAKE) -C "$(POOYAN)" synth

bitstream-pooyan:
	$(MAKE) -C "$(POOYAN)" bitstream

all-pooyan:
	$(MAKE) -C "$(POOYAN)" all

clean-pooyan:
	$(MAKE) -C "$(POOYAN)" clean

# ---- Time-Pilot ----
setup-time-pilot:
	$(MAKE) -C "$(TIME_PILOT)" setup

create-prj-time-pilot:
	$(MAKE) -C "$(TIME_PILOT)" create_prj

clk-wiz-time-pilot:
	$(MAKE) -C "$(TIME_PILOT)" clk_wiz

patch-time-pilot:
	$(MAKE) -C "$(TIME_PILOT)" patch

synth-time-pilot:
	$(MAKE) -C "$(TIME_PILOT)" synth

bitstream-time-pilot:
	$(MAKE) -C "$(TIME_PILOT)" bitstream

all-time-pilot:
	$(MAKE) -C "$(TIME_PILOT)" all

clean-time-pilot:
	$(MAKE) -C "$(TIME_PILOT)" clean

# ---- Bagman ----
setup-bagman:
	$(MAKE) -C "$(BAGMAN)" setup

create-prj-bagman:
	$(MAKE) -C "$(BAGMAN)" create_prj

clk-wiz-bagman:
	$(MAKE) -C "$(BAGMAN)" clk_wiz

patch-bagman:
	$(MAKE) -C "$(BAGMAN)" patch

synth-bagman:
	$(MAKE) -C "$(BAGMAN)" synth

bitstream-bagman:
	$(MAKE) -C "$(BAGMAN)" bitstream

all-bagman:
	$(MAKE) -C "$(BAGMAN)" all

clean-bagman:
	$(MAKE) -C "$(BAGMAN)" clean

.PHONY: help setup-galaga create-prj-galaga clk-wiz-galaga patch-galaga \
        synth-galaga bitstream-galaga all-galaga clean-galaga \
        setup-pooyan clk-wiz-pooyan patch-pooyan synth-pooyan \
        bitstream-pooyan all-pooyan clean-pooyan \
        setup-time-pilot create-prj-time-pilot clk-wiz-time-pilot \
        patch-time-pilot synth-time-pilot bitstream-time-pilot \
        all-time-pilot clean-time-pilot \
        setup-bagman create-prj-bagman clk-wiz-bagman patch-bagman \
        synth-bagman bitstream-bagman all-bagman clean-bagman \
        setup-berzerk create-prj-berzerk clk-wiz-berzerk patch-berzerk \
        synth-berzerk bitstream-berzerk all-berzerk clean-berzerk \
        setup-tron create-prj-tron clk-wiz-tron patch-tron \
        synth-tron bitstream-tron all-tron clean-tron \
        setup-kick create-prj-kick clk-wiz-kick patch-kick \
        synth-kick bitstream-kick all-kick clean-kick \
        setup-traverse-usa create-prj-traverse-usa clk-wiz-traverse-usa \
        patch-traverse-usa synth-traverse-usa bitstream-traverse-usa \
        all-traverse-usa clean-traverse-usa \
        setup-crazy-climber create-prj-crazy-climber clk-wiz-crazy-climber \
        patch-crazy-climber synth-crazy-climber bitstream-crazy-climber \
        all-crazy-climber clean-crazy-climber \
        setup-sky-skipper create-prj-sky-skipper clk-wiz-sky-skipper \
        patch-sky-skipper synth-sky-skipper bitstream-sky-skipper \
        all-sky-skipper clean-sky-skipper

# ---- Berzerk ----
setup-berzerk:
	$(MAKE) -C "$(BERZERK)" setup

create-prj-berzerk:
	$(MAKE) -C "$(BERZERK)" create_prj

clk-wiz-berzerk:
	$(MAKE) -C "$(BERZERK)" clk_wiz

patch-berzerk:
	$(MAKE) -C "$(BERZERK)" patch

synth-berzerk:
	$(MAKE) -C "$(BERZERK)" synth

bitstream-berzerk:
	$(MAKE) -C "$(BERZERK)" bitstream

all-berzerk:
	$(MAKE) -C "$(BERZERK)" all

clean-berzerk:
	$(MAKE) -C "$(BERZERK)" clean

# ---- Tron ----
setup-tron:
	$(MAKE) -C "$(TRON)" setup

create-prj-tron:
	$(MAKE) -C "$(TRON)" create_prj

clk-wiz-tron:
	$(MAKE) -C "$(TRON)" clk_wiz

patch-tron:
	$(MAKE) -C "$(TRON)" patch

synth-tron:
	$(MAKE) -C "$(TRON)" synth

bitstream-tron:
	$(MAKE) -C "$(TRON)" bitstream

all-tron:
	$(MAKE) -C "$(TRON)" all

clean-tron:
	$(MAKE) -C "$(TRON)" clean

# ---- Kick ----
setup-kick:
	$(MAKE) -C "$(KICK)" setup

create-prj-kick:
	$(MAKE) -C "$(KICK)" create_prj

clk-wiz-kick:
	$(MAKE) -C "$(KICK)" clk_wiz

patch-kick:
	$(MAKE) -C "$(KICK)" patch

synth-kick:
	$(MAKE) -C "$(KICK)" synth

bitstream-kick:
	$(MAKE) -C "$(KICK)" bitstream

all-kick:
	$(MAKE) -C "$(KICK)" all

clean-kick:
	$(MAKE) -C "$(KICK)" clean

# ---- BurgerTime ----
setup-burger-time:
	$(MAKE) -C "$(BURGER_TIME)" setup

create-prj-burger-time:
	$(MAKE) -C "$(BURGER_TIME)" create_prj

clk-wiz-burger-time:
	$(MAKE) -C "$(BURGER_TIME)" clk_wiz

patch-burger-time:
	$(MAKE) -C "$(BURGER_TIME)" patch

synth-burger-time:
	$(MAKE) -C "$(BURGER_TIME)" synth

bitstream-burger-time:
	$(MAKE) -C "$(BURGER_TIME)" bitstream

all-burger-time:
	$(MAKE) -C "$(BURGER_TIME)" all

clean-burger-time:
	$(MAKE) -C "$(BURGER_TIME)" clean

# ---- Defender ----
setup-defender:
	$(MAKE) -C "$(DEFENDER)" setup

create-prj-defender:
	$(MAKE) -C "$(DEFENDER)" create_prj

clk-wiz-defender:
	$(MAKE) -C "$(DEFENDER)" clk_wiz

patch-defender:
	$(MAKE) -C "$(DEFENDER)" patch

synth-defender:
	$(MAKE) -C "$(DEFENDER)" synth

bitstream-defender:
	$(MAKE) -C "$(DEFENDER)" bitstream

all-defender:
	$(MAKE) -C "$(DEFENDER)" all

clean-defender:
	$(MAKE) -C "$(DEFENDER)" clean

# ---- Traverse-USA ----
setup-traverse-usa:
	$(MAKE) -C "$(TRAVERSE_USA)" setup

create-prj-traverse-usa:
	$(MAKE) -C "$(TRAVERSE_USA)" create_prj

clk-wiz-traverse-usa:
	$(MAKE) -C "$(TRAVERSE_USA)" clk_wiz

patch-traverse-usa:
	$(MAKE) -C "$(TRAVERSE_USA)" patch

synth-traverse-usa:
	$(MAKE) -C "$(TRAVERSE_USA)" synth

bitstream-traverse-usa:
	$(MAKE) -C "$(TRAVERSE_USA)" bitstream

all-traverse-usa:
	$(MAKE) -C "$(TRAVERSE_USA)" all

clean-traverse-usa:
	$(MAKE) -C "$(TRAVERSE_USA)" clean

# ---- Crazy Kong ----
setup-crazy-kong:
	$(MAKE) -C "$(CRAZY_KONG)" setup

create-prj-crazy-kong:
	$(MAKE) -C "$(CRAZY_KONG)" create_prj

clk-wiz-crazy-kong:
	$(MAKE) -C "$(CRAZY_KONG)" clk_wiz

patch-crazy-kong:
	$(MAKE) -C "$(CRAZY_KONG)" patch

synth-crazy-kong:
	$(MAKE) -C "$(CRAZY_KONG)" synth

bitstream-crazy-kong:
	$(MAKE) -C "$(CRAZY_KONG)" bitstream

all-crazy-kong:
	$(MAKE) -C "$(CRAZY_KONG)" all

clean-crazy-kong:
	$(MAKE) -C "$(CRAZY_KONG)" clean

# ---- Crazy Climber ----
setup-crazy-climber:
	$(MAKE) -C "$(CRAZY_CLIMBER)" setup

create-prj-crazy-climber:
	$(MAKE) -C "$(CRAZY_CLIMBER)" create_prj

clk-wiz-crazy-climber:
	$(MAKE) -C "$(CRAZY_CLIMBER)" clk_wiz

patch-crazy-climber:
	$(MAKE) -C "$(CRAZY_CLIMBER)" patch

synth-crazy-climber:
	$(MAKE) -C "$(CRAZY_CLIMBER)" synth

bitstream-crazy-climber:
	$(MAKE) -C "$(CRAZY_CLIMBER)" bitstream

all-crazy-climber:
	$(MAKE) -C "$(CRAZY_CLIMBER)" all

clean-crazy-climber:
	$(MAKE) -C "$(CRAZY_CLIMBER)" clean

# ---- Sky Skipper ----
setup-sky-skipper:
	$(MAKE) -C "$(SKY_SKIPPER)" setup

create-prj-sky-skipper:
	$(MAKE) -C "$(SKY_SKIPPER)" create_prj

clk-wiz-sky-skipper:
	$(MAKE) -C "$(SKY_SKIPPER)" clk_wiz

patch-sky-skipper:
	$(MAKE) -C "$(SKY_SKIPPER)" patch

synth-sky-skipper:
	$(MAKE) -C "$(SKY_SKIPPER)" synth

bitstream-sky-skipper:
	$(MAKE) -C "$(SKY_SKIPPER)" bitstream

all-sky-skipper:
	$(MAKE) -C "$(SKY_SKIPPER)" all

clean-sky-skipper:
	$(MAKE) -C "$(SKY_SKIPPER)" clean

# ---- Satans Hollow ----
setup-satans-hollow:
	$(MAKE) -C "$(SATANS_HOLLOW)" setup

create-prj-satans-hollow:
	$(MAKE) -C "$(SATANS_HOLLOW)" create_prj

clk-wiz-satans-hollow:
	$(MAKE) -C "$(SATANS_HOLLOW)" clk_wiz

patch-satans-hollow:
	$(MAKE) -C "$(SATANS_HOLLOW)" patch

synth-satans-hollow:
	$(MAKE) -C "$(SATANS_HOLLOW)" synth

bitstream-satans-hollow:
	$(MAKE) -C "$(SATANS_HOLLOW)" bitstream

all-satans-hollow:
	$(MAKE) -C "$(SATANS_HOLLOW)" all

clean-satans-hollow:
	$(MAKE) -C "$(SATANS_HOLLOW)" clean

help:
	@echo "Top-level port driver. Each step delegates to the machine's own Makefile."
	@echo "Usage: make <step>-<machine>"
	@echo
	@echo "Machines and their steps:"
	@echo "  Galaga      : setup create-prj clk-wiz patch synth bitstream all clean"
	@echo "  Pooyan      : setup          clk-wiz patch synth bitstream all clean"
	@echo "  Time-Pilot  : setup create-prj clk-wiz patch synth bitstream all clean"
	@echo "  Bagman      : setup create-prj clk-wiz patch synth bitstream all clean"
	@echo "  Berzerk     : setup create-prj clk-wiz patch synth bitstream all clean"
	@echo "  Tron        : setup create-prj clk-wiz patch synth bitstream all clean"
	@echo "  Kick        : setup create-prj clk-wiz patch synth bitstream all clean"
	@echo "  BurgerTime  : setup create-prj clk-wiz patch synth bitstream all clean"
	@echo "  Defender    : setup create-prj clk-wiz patch synth bitstream all clean"
	@echo "  Traverse-USA: setup create-prj clk-wiz patch synth bitstream all clean"
	@echo "  Crazy Kong  : setup create-prj clk-wiz patch synth bitstream all clean"
	@echo "  Crazy Climber: setup create-prj clk-wiz patch synth bitstream all clean"
	@echo "  Sky Skipper : setup create-prj clk-wiz patch synth bitstream all clean"
	@echo "  Satans Hollow: setup create-prj clk-wiz patch synth bitstream all clean"
	@echo
	@echo "Examples:"
	@echo "  make setup-galaga      make synth-time-pilot      make bitstream-pooyan"