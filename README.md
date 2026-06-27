# SystemVerilog Tomasulo / OoO Processor Project

This project is a staged SystemVerilog implementation of hardware building blocks for a small Tomasulo-style out-of-order processor backend.

The goal is to build the design step by step, starting from simple reusable RTL modules and gradually moving toward reservation stations, a reorder buffer, CDB writeback, register renaming, and eventually load/store handling.

## Current Status

Implemented and tested:

- Combinational ALU
- Parameterized register file
- Fixed-latency functional unit
- FIFO / circular queue
- Self-checking SystemVerilog testbenches
- Verilator simulation workflow
- GTKWave waveform generation

## Project Structure

```text
sv-tomasulo/
├── rtl/
│   └── common/
│       ├── alu.sv
│       ├── regfile.sv
│       ├── fixed_latency_fu.sv
│       └── fifo.sv
├── tb/
│   └── common/
│       ├── alu_tb.sv
│       ├── regfile_tb.sv
│       ├── fixed_latency_fu_tb.sv
│       └── fifo_tb.sv
├── docs/
├── scripts/
├── sim/
├── Makefile
└── README.md
```

## Tools

This project currently uses:

- SystemVerilog
- Verilator
- GTKWave
- GNU Make

## Running Tests

Run all tests:

```bash
make sim
```

Run individual tests:

```bash
make sim_alu
make sim_regfile
make sim_fu
make sim_fifo
```

Run lint checks:

```bash
make lint
```

Clean build and waveform files:

```bash
make clean
```

## Viewing Waveforms

After running a simulation, open the waveform with:

```bash
make wave_alu
make wave_regfile
make wave_fu
make wave_fifo
```

## Implemented Modules

### ALU

A combinational arithmetic/logic unit supporting basic integer operations such as add, subtract, bitwise logic, and set-less-than.

### Register File

A parameterized register file with:

- two combinational read ports
- one synchronous write port
- active-low reset
- hardwired zero register

### Fixed-Latency Functional Unit

A clocked functional unit wrapper that:

- accepts an operation when idle
- stores operands and a destination tag
- remains busy for a fixed number of cycles
- outputs a result and tag with `result_valid`

This will later connect to reservation stations and the common data bus.

### FIFO / Circular Queue

A parameterized circular queue with:

- ready/valid push interface
- ready/valid pop interface
- head and tail pointers
- occupancy count
- full and empty behavior

This is preparation for the future reorder buffer.

## Planned Next Steps

Near-term modules:

1. ROB skeleton / circular commit queue
2. Reservation station
3. CDB arbiter
4. Rename table
5. Tiny Tomasulo backend integration

Longer-term features:

- in-order commit
- load/store queue
- memory ordering
- branch handling
- direct-mapped L1 data cache
- trace/debug infrastructure
