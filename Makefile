TOP=alu_tb

RTL=rtl/common/alu.sv
TB=tb/common/alu_tb.sv

.PHONY: sim wave lint clean

sim:
	verilator --binary --trace --timing -Wall -Wno-fatal \
		--top-module $(TOP) \
		$(RTL) $(TB)
	./obj_dir/V$(TOP)

wave:
	gtkwave alu_tb.vcd

lint:
	verilator --lint-only -Wall -Wno-fatal \
		--top-module $(TOP) \
		$(RTL) $(TB)

clean:
	rm -rf obj_dir *.vcd