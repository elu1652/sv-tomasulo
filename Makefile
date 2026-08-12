VERILATOR := verilator

SIM_FLAGS  := --binary --trace --timing -Wall -Wno-fatal
LINT_FLAGS := --lint-only --timing -Wall -Wno-fatal

CORE_PKG := rtl/core/core_pkg.sv

.DEFAULT_GOAL := sim

# --------------------------------------------------------------------
# Test source lists
# --------------------------------------------------------------------

ALU_SRCS := \
	rtl/common/alu.sv \
	tb/common/alu_tb.sv

REGFILE_SRCS := \
	rtl/common/regfile.sv \
	tb/common/regfile_tb.sv

FU_SRCS := \
	rtl/common/fixed_latency_fu.sv \
	tb/common/fixed_latency_fu_tb.sv

FIFO_SRCS := \
	rtl/common/fifo.sv \
	tb/common/fifo_tb.sv

ROB_SRCS := \
	rtl/core/rob.sv \
	tb/core/rob_tb.sv

RS_SRCS := \
	rtl/core/reservation_station.sv \
	tb/core/reservation_station_tb.sv

CDB_SRCS := \
	rtl/core/cdb.sv \
	tb/core/cdb_tb.sv

BACKEND_WRITEBACK_SRCS := \
	rtl/core/rob.sv \
	rtl/core/reservation_station.sv \
	rtl/common/fixed_latency_fu.sv \
	rtl/core/cdb.sv \
	tb/core/backend_writeback_tb.sv

BACKEND_DEPENDENCY_SRCS := \
	rtl/core/rob.sv \
	rtl/core/reservation_station.sv \
	rtl/common/fixed_latency_fu.sv \
	rtl/core/cdb.sv \
	tb/core/backend_dependency_tb.sv

BACKEND_RENAME_SRCS := \
	rtl/common/regfile.sv \
	rtl/common/fixed_latency_fu.sv \
	rtl/core/rename_table.sv \
	rtl/core/rob.sv \
	rtl/core/reservation_station.sv \
	rtl/core/cdb.sv \
	rtl/core/dispatch.sv \
	tb/core/backend_rename_tb.sv

RENAME_TABLE_SRCS := \
	rtl/core/rename_table.sv \
	tb/core/rename_table_tb.sv

DISPATCH_SRCS := \
	rtl/core/dispatch.sv \
	tb/core/dispatch_tb.sv

CDB_ARBITER_SRCS := \
	rtl/core/cdb_arbiter.sv \
	tb/core/cdb_arbiter_tb.sv

BACKEND_OOO_SRCS := \
	rtl/common/regfile.sv \
	rtl/common/fixed_latency_fu.sv \
	rtl/core/dispatch.sv \
	rtl/core/rename_table.sv \
	rtl/core/rob.sv \
	rtl/core/reservation_station.sv \
	rtl/core/cdb_arbiter.sv \
	tb/core/backend_ooo_tb.sv

BACKEND_CROSS_FU_DEPENDENCY_SRCS := \
	rtl/common/regfile.sv \
	rtl/common/fixed_latency_fu.sv \
	rtl/core/dispatch.sv \
	rtl/core/rename_table.sv \
	rtl/core/rob.sv \
	rtl/core/reservation_station.sv \
	rtl/core/cdb_arbiter.sv \
	tb/core/backend_cross_fu_dependency_tb.sv

BACKEND_CDB_COLLISION_SRCS := \
	rtl/common/regfile.sv \
	rtl/common/fixed_latency_fu.sv \
	rtl/core/dispatch.sv \
	rtl/core/rename_table.sv \
	rtl/core/rob.sv \
	rtl/core/reservation_station.sv \
	rtl/core/cdb_arbiter.sv \
	tb/core/backend_cdb_collision_tb.sv

BACKEND_SRCS := \
	rtl/common/regfile.sv \
	rtl/common/fixed_latency_fu.sv \
	rtl/core/dispatch.sv \
	rtl/core/rename_table.sv \
	rtl/core/rob.sv \
	rtl/core/reservation_station.sv \
	rtl/core/cdb_arbiter.sv \
	rtl/core/backend.sv \
	tb/core/backend_tb.sv

# --------------------------------------------------------------------
# Helper macros
# --------------------------------------------------------------------

define SIM_TEMPLATE
sim_$(1):
	@echo
	@echo "[BUILD] $(1)"
	@mkdir -p obj_dir/$(1) waves
	@$$(VERILATOR) $$(SIM_FLAGS) \
		--Mdir obj_dir/$(1) \
		--top-module $(2) \
		$$(CORE_PKG) \
		$$($(3)_SRCS) \
		> obj_dir/$(1)/build.log 2>&1 || { \
			echo "[ERROR] $(1) build failed"; \
			cat obj_dir/$(1)/build.log; \
			exit 1; \
		}
	@echo "[TEST]  $(1)"
	@./obj_dir/$(1)/V$(2)
endef

define LINT_TEMPLATE
lint_$(1):
	@echo "[LINT]  $(1)"
	@mkdir -p obj_dir/$(1)
	@$$(VERILATOR) $$(LINT_FLAGS) \
		--top-module $(2) \
		$$(CORE_PKG) \
		$$($(3)_SRCS) \
		> obj_dir/$(1)/lint.log 2>&1 || { \
			cat obj_dir/$(1)/lint.log; \
			exit 1; \
		}
endef


# --------------------------------------------------------------------
# Generate sim/lint targets
# --------------------------------------------------------------------

$(eval $(call SIM_TEMPLATE,alu,alu_tb,ALU))
$(eval $(call SIM_TEMPLATE,regfile,regfile_tb,REGFILE))
$(eval $(call SIM_TEMPLATE,fu,fixed_latency_fu_tb,FU))
$(eval $(call SIM_TEMPLATE,fifo,fifo_tb,FIFO))
$(eval $(call SIM_TEMPLATE,rob,rob_tb,ROB))
$(eval $(call SIM_TEMPLATE,rs,reservation_station_tb,RS))
$(eval $(call SIM_TEMPLATE,cdb,cdb_tb,CDB))
$(eval $(call SIM_TEMPLATE,backend_writeback,backend_writeback_tb,BACKEND_WRITEBACK))
$(eval $(call SIM_TEMPLATE,backend_dependency,backend_dependency_tb,BACKEND_DEPENDENCY))
$(eval $(call SIM_TEMPLATE,rename_table,rename_table_tb,RENAME_TABLE))
$(eval $(call SIM_TEMPLATE,backend_rename,backend_rename_tb,BACKEND_RENAME))
$(eval $(call SIM_TEMPLATE,dispatch,dispatch_tb,DISPATCH))
$(eval $(call SIM_TEMPLATE,cdb_arbiter,cdb_arbiter_tb,CDB_ARBITER))
$(eval $(call SIM_TEMPLATE,backend_ooo,backend_ooo_tb,BACKEND_OOO))
$(eval $(call SIM_TEMPLATE,backend_cross_fu_dependency,backend_cross_fu_dependency_tb,BACKEND_CROSS_FU_DEPENDENCY))
$(eval $(call SIM_TEMPLATE,backend_cdb_collision,backend_cdb_collision_tb,BACKEND_CDB_COLLISION))
$(eval $(call SIM_TEMPLATE,backend,backend_tb,BACKEND))

$(eval $(call LINT_TEMPLATE,alu,alu_tb,ALU))
$(eval $(call LINT_TEMPLATE,regfile,regfile_tb,REGFILE))
$(eval $(call LINT_TEMPLATE,fu,fixed_latency_fu_tb,FU))
$(eval $(call LINT_TEMPLATE,fifo,fifo_tb,FIFO))
$(eval $(call LINT_TEMPLATE,rob,rob_tb,ROB))
$(eval $(call LINT_TEMPLATE,rs,reservation_station_tb,RS))
$(eval $(call LINT_TEMPLATE,cdb,cdb_tb,CDB))
$(eval $(call LINT_TEMPLATE,backend_writeback,backend_writeback_tb,BACKEND_WRITEBACK))
$(eval $(call LINT_TEMPLATE,backend_dependency,backend_dependency_tb,BACKEND_DEPENDENCY))
$(eval $(call LINT_TEMPLATE,rename_table,rename_table_tb,RENAME_TABLE))
$(eval $(call LINT_TEMPLATE,backend_rename,backend_rename_tb,BACKEND_RENAME))
$(eval $(call LINT_TEMPLATE,dispatch,dispatch_tb,DISPATCH))
$(eval $(call LINT_TEMPLATE,cdb_arbiter,cdb_arbiter_tb,CDB_ARBITER))
$(eval $(call LINT_TEMPLATE,backend_ooo,backend_ooo_tb,BACKEND_OOO))
$(eval $(call LINT_TEMPLATE,backend_cross_fu_dependency,backend_cross_fu_dependency_tb,BACKEND_CROSS_FU_DEPENDENCY))
$(eval $(call LINT_TEMPLATE,backend_cdb_collision,backend_cdb_collision_tb,BACKEND_CDB_COLLISION))
$(eval $(call LINT_TEMPLATE,backend,backend_tb,BACKEND))


# --------------------------------------------------------------------
# Aggregate targets
# --------------------------------------------------------------------

.PHONY: sim lint clean \
	sim_alu sim_regfile sim_fu sim_fifo sim_rob sim_rs sim_cdb \
	sim_backend_writeback sim_backend_dependency sim_rename_table \
	sim_backend_rename sim_dispatch sim_cdb_arbiter sim_backend_ooo \
	sim_backend_cross_fu_dependency sim_backend_cdb_collision sim_backend \
	lint_alu lint_regfile lint_fu lint_fifo lint_rob lint_rs lint_cdb \
	lint_backend_writeback lint_backend_dependency lint_rename_table\
	lint_backend_rename lint_dispatch lint_cdb_arbiter lint_backend_ooo \
	lint_backend_cross_fu_dependency lint_backend_cdb_collision lint_backend \
	wave_alu wave_regfile wave_fu wave_fifo wave_rob wave_rs wave_cdb \
	wave_backend_writeback wave_backend_dependency wave_rename_table wave_backend_rename \
	wave_dispatch \
	wave_cdb_arbiter \
	wave_backend_ooo \
	wave_backend_cross_fu_dependency \
	wave_backend_cdb_collision \
	wave_backend

sim: sim_alu sim_regfile sim_fu sim_fifo sim_rob sim_rs sim_cdb sim_backend_writeback sim_backend_dependency sim_rename_table sim_backend_rename sim_dispatch sim_cdb_arbiter sim_backend_ooo sim_backend_cross_fu_dependency sim_backend_cdb_collision sim_backend
	@echo
	@echo "================================"
	@echo "ALL TESTS PASSED"
	@echo "================================"

lint: lint_alu lint_regfile lint_fu lint_fifo lint_rob lint_rs lint_cdb lint_backend_writeback lint_backend_dependency lint_rename_table lint_backend_rename lint_dispatch lint_cdb_arbiter lint_backend_ooo lint_backend_cross_fu_dependency lint_backend_cdb_collision lint_backend
	@echo
	@echo "ALL LINT CHECKS PASSED"


# --------------------------------------------------------------------
# Wave targets
# --------------------------------------------------------------------

wave_alu:
	@gtkwave alu_tb.vcd

wave_regfile:
	@gtkwave regfile_tb.vcd

wave_fu:
	@gtkwave fixed_latency_fu_tb.vcd

wave_fifo:
	@gtkwave fifo_tb.vcd

wave_rob:
	@gtkwave rob_tb.vcd

wave_rs:
	@gtkwave reservation_station_tb.vcd

wave_cdb:
	@gtkwave cdb_tb.vcd

wave_backend_writeback:
	@gtkwave backend_writeback_tb.vcd

wave_backend_dependency:
	@gtkwave backend_dependency_tb.vcd

wave_rename_table:
	@gtkwave rename_table_tb.vcd

wave_backend_rename:
	@gtkwave backend_rename_tb.vcd

wave_dispatch:
	@gtkwave dispatch_tb.vcd

wave_cdb_arbiter:
	@gtkwave cdb_arbiter_tb.vcd

wave_backend_ooo:
	@gtkwave backend_ooo_tb.vcd

wave_backend_cross_fu_dependency:
	@gtkwave backend_cross_fu_dependency_tb.vcd

wave_backend_cdb_collision:
	@gtkwave backend_cdb_collision_tb.vcd

wave_backend:
	@gtkwave waves/backend_tb.vcd

# --------------------------------------------------------------------
# Cleanup
# --------------------------------------------------------------------

clean:
	@rm -rf obj_dir *.vcd *.fst
	@echo "Build and waveform files removed"
