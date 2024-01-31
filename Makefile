NOVAS        := /eda/tools/snps/verdi/R-2020.12/share/PLI/VCS/LINUX64
EXTRA        := -P ${NOVAS}/novas.tab ${NOVAS}/pli.a

VERDI_TOOL   := verdi
SIM_TOOL     := vcs
SIM_OPTIONS  := -full64 -debug_acc+all  +v2k -sverilog -timescale=1ns/10ps \
                ${EXTRA} \
                +error+500\
                +define+SVA_OFF\
                -work DEFAULT\
                +vcs+flush+all \
                +lint=TFIPC-L \
                +define+S50 \
                -kdb \

SIM_APP  ?= axi4_sram_fsm

SRC_FILE ?=
ifeq ($(SIM_APP), axi4_sram_bpl)
SRC_FILE += ../rtl/addr_gen.sv
SRC_FILE += ../rtl/addr_ctrl.sv
SRC_FILE += ../rtl/mem_ctrl.sv
SRC_FILE += ../rtl/axi4_sram_bpl.sv
SRC_FILE += ../tb/sram_test.sv
SRC_FILE += ../tb/test_top.sv
SRC_FILE += ../tb/axi4_sram_bpl_tb.sv
endif
ifeq ($(SIM_APP), axi4_sram_fsm)
SRC_FILE += ../rtl/axi4_sram_fsm.sv
SRC_FILE += ../tb/sram_test.sv
SRC_FILE += ../tb/test_top.sv
SRC_FILE += ../tb/axi4_sram_fsm_tb.sv
endif

SIM_INC ?=
SIM_INC += +incdir+../rtl/
SIM_INC += +incdir+../../common/rtl/
SIM_INC += +incdir+../../common/rtl/tech
SIM_INC += +incdir+../../common/rtl/verif
SIM_INC += +incdir+../../common/rtl/interface


SIM_TOP  := $(SIM_APP)_tb

WAVE_CFG ?= # WAVE_ON
RUN_ARGS ?=
RUN_ARGS += +${WAVE_CFG}
RUN_ARGS += +WAVE_NAME=$(SIM_TOP).fsdb

comp:
	@mkdir -p build
	cd build && (${SIM_TOOL} ${SIM_OPTIONS} -top $(SIM_TOP) -l compile.log $(SRC_FILE) $(SIM_INC))

run: comp
	cd build && ./simv -l run.log ${RUN_ARGS}

wave:
	${VERDI_TOOL} -ssf build/$(SIM_TOP).fsdb &

clean:
	rm -rf build
	rm -rf verdiLog
	rm -rf novas.*

.PHONY: wave clean
