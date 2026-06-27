# SystemVerilog Tomasulo / OoO Processor Project

This project is a staged SystemVerilog implementation of hardware building blocks for a small Tomasulo-style out-of-order processor backend.

The goal is to build the design step by step, starting from simple reusable RTL modules and gradually moving toward reservation stations, a reorder buffer, CDB writeback, register renaming, and eventually load/store handling.

## Current Status

Implemented and tested:

* Combinational ALU
* Parameterized register file
* Fixed-latency functional unit
* FIFO / circular queue
* Reorder Buffer skeleton
* Self-checking SystemVerilog testbenches
* Verilator simulation workflow
* GTKWave waveform generation

## Implemented Modules

### ALU

A combinational arithmetic/logic unit supporting basic operations such as add, subtract, bitwise logic, and signed set-less-than.

### Register File

A small parameterized architectural register file with two combinational read ports, one synchronous write port, reset behavior, and R0 hardwired to zero.

### Fixed-Latency Functional Unit

A simple multi-cycle functional unit that accepts an operation, operands, and an input tag, then produces a result and matching output tag after a fixed latency.

This models the future execution unit behavior used in a Tomasulo-style backend.

### FIFO / Circular Queue

A parameterized ready/valid FIFO using head and tail pointers, occupancy count, full/empty detection, and wraparound behavior.

This module helped establish the circular-buffer logic later reused by the ROB.

### Reorder Buffer Skeleton

A simple reorder buffer that supports:

* In-order allocation at the tail
* ROB tag generation
* Out-of-order writeback by tag
* In-order commit from the head
* Ready/valid tracking per entry
* Destination register and result value storage
* Full/empty tracking through an occupancy count
* Circular head/tail wraparound

The ROB demonstrates a core out-of-order execution idea: instructions may finish out of order, but they commit in program order.

Example tested behavior:

* Allocate ROB0, ROB1, ROB2
* Write back ROB1 before ROB0
* Confirm ROB1 cannot commit yet
* Write back ROB0
* Commit ROB0 first
* Commit ROB1 next

This proves that the design allows out-of-order completion while preserving in-order architectural state updates.

## Build and Run

Run all simulations:

```bash
make sim
```

Run only the ROB test:

```bash
make sim_rob
```

Open the ROB waveform:

```bash
make wave_rob
```

Clean generated files:

```bash
make clean
```

## Tools

* SystemVerilog
* Verilator
* GTKWave
* Make
* Linux development environment

## Planned Next Steps

Near-term:

1. Add a reservation station module.
2. Connect reservation station dispatch to the fixed-latency functional unit.
3. Add a simple CDB-style writeback path.
4. Connect FU writeback into the ROB.
5. Add a small rename table.

Longer-term:

1. Build a tiny integrated Tomasulo backend.
2. Support register renaming and operand wakeup.
3. Add in-order commit to the architectural register file.
4. Add load/store queue behavior.
5. Add branch recovery.
6. Add a simple cache/memory model.
