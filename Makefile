VERILATOR := verilator

SIM_FLAGS  := --binary --trace --timing -Wall -Wno-fatal
LINT_FLAGS := --lint-only --timing -Wall -Wno-fatal

.PHONY: \
	sim sim_alu sim_regfile sim_fu sim_fifo sim_rob sim_rs sim_cdb\
	wave_alu wave_regfile wave_fu wave_fifo wave_rob wave_rs wave_cdb \
	lint lint_alu lint_regfile lint_fu lint_fifo lint_rob lint_rs lint_cdb \
	clean

sim: sim_alu sim_regfile sim_fu sim_fifo sim_rob sim_rs sim_cdb
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

sim_rob:
	@echo
	@echo "[BUILD] ROB"
	@mkdir -p obj_dir/rob
	@$(VERILATOR) $(SIM_FLAGS) \
		--Mdir obj_dir/rob \
		--top-module rob_tb \
		rtl/core/rob.sv \
		tb/core/rob_tb.sv \
		> obj_dir/rob/build.log 2>&1 || { \
			echo "[ERROR] ROB build failed"; \
			cat obj_dir/rob/build.log; \
			exit 1; \
		}
	@echo "[TEST]  ROB"
	@./obj_dir/rob/Vrob_tb

sim_rs:
	@echo
	@echo "[BUILD] Reservation station"
	@mkdir -p obj_dir/rs
	@$(VERILATOR) $(SIM_FLAGS) \
		--Mdir obj_dir/rs \
		--top-module reservation_station_tb \
		rtl/core/reservation_station.sv \
		tb/core/reservation_station_tb.sv \
		> obj_dir/rs/build.log 2>&1 || { \
			echo "[ERROR] Reservation station build failed"; \
			cat obj_dir/rs/build.log; \
			exit 1; \
		}
	@echo "[TEST]  Reservation station"
	@./obj_dir/rs/Vreservation_station_tb

sim_cdb:
	@echo
	@echo "[BUILD] CDB"
	@mkdir -p obj_dir/cdb
	@$(VERILATOR) $(SIM_FLAGS) \
		--Mdir obj_dir/cdb \
		--top-module cdb_tb \
		rtl/core/cdb.sv \
		tb/core/cdb_tb.sv \
		> obj_dir/cdb/build.log 2>&1 || { \
			echo "[ERROR] CDB build failed"; \
			cat obj_dir/cdb/build.log; \
			exit 1; \
		}
	@echo "[TEST]  CDB"
	@./obj_dir/cdb/Vcdb_tb

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

lint: lint_alu lint_regfile lint_fu lint_fifo lint_rob lint_rs lint_cdb
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

lint_rob:
	@echo "[LINT]  ROB"
	@mkdir -p obj_dir/rob
	@$(VERILATOR) $(LINT_FLAGS) \
		--top-module rob_tb \
		rtl/core/rob.sv \
		tb/core/rob_tb.sv \
		> obj_dir/rob/lint.log 2>&1 || { \
			cat obj_dir/rob/lint.log; \
			exit 1; \
		}

lint_rs:
	@echo "[LINT]  Reservation station"
	@mkdir -p obj_dir/rs
	@$(VERILATOR) $(LINT_FLAGS) \
		--top-module reservation_station_tb \
		rtl/core/reservation_station.sv \
		tb/core/reservation_station_tb.sv \
		> obj_dir/rs/lint.log 2>&1 || { \
			cat obj_dir/rs/lint.log; \
			exit 1; \
		}

lint_cdb:
	@echo "[LINT]  CDB"
	@mkdir -p obj_dir/cdb
	@$(VERILATOR) $(LINT_FLAGS) \
		--top-module cdb_tb \
		rtl/core/cdb.sv \
		tb/core/cdb_tb.sv \
		> obj_dir/cdb/lint.log 2>&1 || { \
			cat obj_dir/cdb/lint.log; \
			exit 1; \
		}

clean:
	@rm -rf obj_dir *.vcd *.fst
	@echo "Build and waveform files removed"
