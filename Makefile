VERILATOR := verilator

SIM_FLAGS  := --binary --trace --timing -Wall -Wno-fatal
LINT_FLAGS := --lint-only --timing -Wall -Wno-fatal

.PHONY: \
	sim sim_alu sim_regfile sim_fu sim_fifo \
	wave_alu wave_regfile wave_fu wave_fifo \
	lint lint_alu lint_regfile lint_fu lint_fifo \
	clean

sim: sim_alu sim_regfile sim_fu sim_fifo
	@echo
	@echo "================================"
	@echo "ALL TESTS PASSED"
	@echo "================================"

sim_alu:
	@echo
	@echo "[BUILD] ALU"
	@mkdir -p obj_dir/alu
	@$(VERILATOR) $(SIM_FLAGS) \
		--Mdir obj_dir/alu \
		--top-module alu_tb \
		rtl/common/alu.sv \
		tb/common/alu_tb.sv \
		> obj_dir/alu/build.log 2>&1 || { \
			echo "[ERROR] ALU build failed"; \
			cat obj_dir/alu/build.log; \
			exit 1; \
		}
	@echo "[TEST]  ALU"
	@./obj_dir/alu/Valu_tb

sim_regfile:
	@echo
	@echo "[BUILD] Register file"
	@mkdir -p obj_dir/regfile
	@$(VERILATOR) $(SIM_FLAGS) \
		--Mdir obj_dir/regfile \
		--top-module regfile_tb \
		rtl/common/regfile.sv \
		tb/common/regfile_tb.sv \
		> obj_dir/regfile/build.log 2>&1 || { \
			echo "[ERROR] Register-file build failed"; \
			cat obj_dir/regfile/build.log; \
			exit 1; \
		}
	@echo "[TEST]  Register file"
	@./obj_dir/regfile/Vregfile_tb

sim_fu:
	@echo
	@echo "[BUILD] Fixed-latency FU"
	@mkdir -p obj_dir/fu
	@$(VERILATOR) $(SIM_FLAGS) \
		--Mdir obj_dir/fu \
		--top-module fixed_latency_fu_tb \
		rtl/common/fixed_latency_fu.sv \
		tb/common/fixed_latency_fu_tb.sv \
		> obj_dir/fu/build.log 2>&1 || { \
			echo "[ERROR] Fixed-latency FU build failed"; \
			cat obj_dir/fu/build.log; \
			exit 1; \
		}
	@echo "[TEST]  Fixed-latency FU"
	@./obj_dir/fu/Vfixed_latency_fu_tb

sim_fifo:
	@echo
	@echo "[BUILD] FIFO"
	@mkdir -p obj_dir/fifo
	@$(VERILATOR) $(SIM_FLAGS) \
		--Mdir obj_dir/fifo \
		--top-module fifo_tb \
		rtl/common/fifo.sv \
		tb/common/fifo_tb.sv \
		> obj_dir/fifo/build.log 2>&1 || { \
			echo "[ERROR] FIFO build failed"; \
			cat obj_dir/fifo/build.log; \
			exit 1; \
		}
	@echo "[TEST]  FIFO"
	@./obj_dir/fifo/Vfifo_tb

wave_alu:
	@gtkwave alu_tb.vcd

wave_regfile:
	@gtkwave regfile_tb.vcd

wave_fu:
	@gtkwave fixed_latency_fu_tb.vcd

wave_fifo:
	@gtkwave fifo_tb.vcd

lint: lint_alu lint_regfile lint_fu lint_fifo
	@echo
	@echo "ALL LINT CHECKS PASSED"

lint_alu:
	@echo "[LINT]  ALU"
	@mkdir -p obj_dir/alu
	@$(VERILATOR) $(LINT_FLAGS) \
		--top-module alu_tb \
		rtl/common/alu.sv \
		tb/common/alu_tb.sv \
		> obj_dir/alu/lint.log 2>&1 || { \
			cat obj_dir/alu/lint.log; \
			exit 1; \
		}

lint_regfile:
	@echo "[LINT]  Register file"
	@mkdir -p obj_dir/regfile
	@$(VERILATOR) $(LINT_FLAGS) \
		--top-module regfile_tb \
		rtl/common/regfile.sv \
		tb/common/regfile_tb.sv \
		> obj_dir/regfile/lint.log 2>&1 || { \
			cat obj_dir/regfile/lint.log; \
			exit 1; \
		}

lint_fu:
	@echo "[LINT]  Fixed-latency FU"
	@mkdir -p obj_dir/fu
	@$(VERILATOR) $(LINT_FLAGS) \
		--top-module fixed_latency_fu_tb \
		rtl/common/fixed_latency_fu.sv \
		tb/common/fixed_latency_fu_tb.sv \
		> obj_dir/fu/lint.log 2>&1 || { \
			cat obj_dir/fu/lint.log; \
			exit 1; \
		}

lint_fifo:
	@echo "[LINT]  FIFO"
	@mkdir -p obj_dir/fifo
	@$(VERILATOR) $(LINT_FLAGS) \
		--top-module fifo_tb \
		rtl/common/fifo.sv \
		tb/common/fifo_tb.sv \
		> obj_dir/fifo/lint.log 2>&1 || { \
			cat obj_dir/fifo/lint.log; \
			exit 1; \
		}

clean:
	@rm -rf obj_dir *.vcd *.fst
	@echo "Build and waveform files removed"
