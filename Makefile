VERILATOR = verilator
FLAGS = --binary --trace --timing -Wall -Wno-fatal

.PHONY: sim sim_alu sim_regfile wave_alu wave_regfile lint_alu lint_regfile clean

sim: sim_alu sim_regfile

sim_alu:
	mkdir -p obj_dir/alu
	$(VERILATOR) $(FLAGS) \
		--Mdir obj_dir/alu \
		--top-module alu_tb \
		rtl/common/alu.sv \
		tb/common/alu_tb.sv
	./obj_dir/alu/Valu_tb

sim_regfile:
	mkdir -p obj_dir/regfile
	$(VERILATOR) $(FLAGS) \
		--Mdir obj_dir/regfile \
		--top-module regfile_tb \
		rtl/common/regfile.sv \
		tb/common/regfile_tb.sv
	./obj_dir/regfile/Vregfile_tb

wave_alu:
	gtkwave alu_tb.vcd

wave_regfile:
	gtkwave regfile_tb.vcd

lint_alu:
	$(VERILATOR) --lint-only --timing -Wall -Wno-fatal \
		--top-module alu_tb \
		rtl/common/alu.sv \
		tb/common/alu_tb.sv

lint_regfile:
	$(VERILATOR) --lint-only --timing -Wall -Wno-fatal \
		--top-module regfile_tb \
		rtl/common/regfile.sv \
		tb/common/regfile_tb.sv

clean:
	rm -rf obj_dir *.vcd *.fst