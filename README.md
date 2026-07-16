# SystemVerilog Tomasulo / OoO Processor Project

This project is a staged SystemVerilog implementation of a small Tomasulo-style out-of-order execution backend.

The design is being built incrementally using independently verified RTL modules before integrating them into a complete backend.

The main architectural goal is to demonstrate:

```text
out-of-order execution + in-order commit
````

The current design supports tagged dependencies, reservation-station wakeup, fixed-latency execution, CDB-style result broadcast, ROB-based writeback and commit, register renaming, and committed architectural register state.

---

## Current Status

Implemented and tested:

* Combinational ALU
* Parameterized architectural register file
* Fixed-latency functional unit
* FIFO / circular queue
* Reorder buffer
* Reservation station
* Common data bus
* Rename table
* RS → FU → CDB → ROB writeback integration
* Dependency wakeup through CDB tags
* Rename-table and register-file integration
* ROB commit into architectural register state
* Self-checking SystemVerilog testbenches
* Cycle-based event logging
* Verilator simulation and lint workflow
* GTKWave waveform generation

The current integrated backend can execute a sequence such as:

```asm
ADD R1, R2, R3
ADD R4, R1, R5
```

The second instruction detects that `R1` is pending, waits on the producing ROB tag, wakes when the result is broadcast on the CDB, executes, and later commits in program order.

---

## Implemented Modules

### ALU

File:

```text
rtl/common/alu.sv
```

A combinational arithmetic and logic unit supporting:

* ADD
* SUB
* AND
* OR
* XOR
* Signed set-less-than
* Zero-result detection

The ALU contains no clocked state. Outputs respond combinationally to input changes.

---

### Register File

File:

```text
rtl/common/regfile.sv
```

A parameterized architectural register file with:

* Two combinational read ports
* One synchronous write port
* Active-low reset
* Hardwired zero register
* Parameterized data width and register count

In the integrated backend, the register file represents committed architectural state. It is updated by ROB commit rather than speculative execution.

---

### Fixed-Latency Functional Unit

File:

```text
rtl/common/fixed_latency_fu.sv
```

A multi-cycle execution unit that accepts:

```text
operation
operand A
operand B
destination ROB tag
```

After a configurable latency, it produces:

```text
result_valid
result value
matching destination tag
```

The tag travels with the operation so the result can be written back to the correct ROB entry.

---

### FIFO / Circular Queue

File:

```text
rtl/common/fifo.sv
```

A parameterized ready/valid FIFO implementing:

* Head and tail pointers
* Occupancy count
* Push and pop handshakes
* Full and empty detection
* Pointer wraparound

This module established the circular-buffer concepts later used by the ROB.

---

### Reorder Buffer

File:

```text
rtl/core/rob.sv
```

The ROB supports:

* In-order allocation at the tail
* ROB tag generation
* Out-of-order writeback by tag
* Ready tracking for completed instructions
* In-order commit from the head
* Destination register storage
* Result value storage
* Full and empty detection
* Circular head and tail wraparound

The key commit condition is:

```text
head entry is valid and ready
```

Instructions may complete out of order, but architectural updates occur in program order.

Example tested behavior:

```text
Allocate ROB0, ROB1, ROB2
Write back ROB1 before ROB0
ROB1 cannot commit because ROB0 is still at the head
Write back ROB0
Commit ROB0
Commit ROB1
```

---

### Reservation Station

File:

```text
rtl/core/reservation_station.sv
```

The reservation station stores instructions until both operands are ready.

Each entry tracks:

```text
busy
operation

source 1 ready/value/tag
source 2 ready/value/tag

destination ROB tag
```

A source operand may be stored as either:

```text
ready value
```

or:

```text
waiting ROB tag
```

When the CDB broadcasts a matching tag, the reservation station captures the value and marks the operand ready.

The current implementation:

* Accepts one dispatch per cycle
* Issues one ready instruction per cycle
* Supports CDB operand wakeup
* Selects the lowest-index ready entry
* Tracks occupancy
* Frees an entry after issue

Oldest-ready scheduling and multiple functional units are future extensions.

---

### Common Data Bus

File:

```text
rtl/core/cdb.sv
```

The current CDB is a combinational tagged broadcast path from one functional unit.

It broadcasts:

```text
valid
ROB destination tag
result value
```

The same broadcast is observed by:

* The ROB for result writeback
* Reservation stations for operand wakeup

Because the current design has one FU, no arbitration is required yet. A future multi-FU implementation will add arbitration and result holding.

---

### Rename Table

File:

```text
rtl/core/rename_table.sv
```

The rename table tracks the newest in-flight producer of each architectural register.

Each entry stores:

```text
producer valid
producer ROB tag
```

For a source-register lookup:

```text
not pending -> read committed value from register file
pending     -> send producer ROB tag to reservation station
```

When a new instruction writes a destination register:

```text
destination register -> allocated ROB tag
```

At commit, the mapping is cleared only if the committing ROB tag is still the current producer.

This prevents an older writer from incorrectly clearing a newer mapping during a WAW dependency.

Example:

```text
I0 writes R1 -> ROB0
I1 writes R1 -> ROB1

When ROB0 commits:
R1 must continue pointing to ROB1
```

---

## Integration Tests

### Backend Writeback Test

File:

```text
tb/core/backend_writeback_tb.sv
```

Verifies:

```text
RS issue
-> FU execution
-> CDB broadcast
-> ROB writeback
-> in-order commit
```

Example:

```text
ADD 10 + 20
result tagged for ROB0
ROB0 receives 30
ROB0 commits 30
```

---

### Backend Dependency Test

File:

```text
tb/core/backend_dependency_tb.sv
```

Verifies CDB-based dependency wakeup.

Example:

```asm
I0: ADD R1 = 10 + 20
I1: ADD R2 = R1 + 5
```

`I1` initially waits for the tag assigned to `I0`. When `I0` broadcasts its result, `I1` captures the value, becomes ready, and executes.

---

### Backend Rename Integration Test

File:

```text
tb/core/backend_rename_tb.sv
```

Integrates:

```text
register file
rename table
ROB
reservation station
functional unit
CDB
```

The test starts with:

```text
R2 = 10
R3 = 20
R5 = 5
```

and executes:

```asm
I0: ADD R1, R2, R3
I1: ADD R4, R1, R5
```

Expected behavior:

```text
I0 receives ROB0
R1 is renamed to ROB0

I1 receives ROB1
rename lookup reports that R1 is pending on ROB0
R5 is read from the architectural register file

ROB0 broadcasts 30
I1 wakes and calculates 35

ROB0 commits R1 = 30
ROB1 commits R4 = 35
rename mappings are cleared
```

The test also logs issue, CDB, and commit events by cycle.

Example:

```text
[CYCLE 7]  ISSUE ROB0: 10 + 20
[CYCLE 11] CDB ROB0 = 30
[CYCLE 12] ISSUE ROB1: 30 + 5
[CYCLE 16] CDB ROB1 = 35
```

---

## Project Structure

```text
sv-tomasulo/
├── rtl/
│   ├── common/
│   │   ├── alu.sv
│   │   ├── regfile.sv
│   │   ├── fixed_latency_fu.sv
│   │   └── fifo.sv
│   └── core/
│       ├── rob.sv
│       ├── reservation_station.sv
│       ├── cdb.sv
│       └── rename_table.sv
├── tb/
│   ├── common/
│   │   ├── alu_tb.sv
│   │   ├── regfile_tb.sv
│   │   ├── fixed_latency_fu_tb.sv
│   │   └── fifo_tb.sv
│   └── core/
│       ├── rob_tb.sv
│       ├── reservation_station_tb.sv
│       ├── cdb_tb.sv
│       ├── rename_table_tb.sv
│       ├── backend_writeback_tb.sv
│       ├── backend_dependency_tb.sv
│       └── backend_rename_tb.sv
├── docs/
├── Makefile
├── README.md
└── .gitignore
```

---

## Build and Run

Run all simulations:

```bash
make sim
```

Run all lint checks:

```bash
make lint
```

Run an individual test:

```bash
make sim_rob
make sim_rs
make sim_cdb
make sim_rename_table
make sim_backend_writeback
make sim_backend_dependency
make sim_backend_rename
```

Open a waveform:

```bash
make wave_rob
make wave_rs
make wave_backend_rename
```

Remove generated files:

```bash
make clean
```

---

## Testbench Timing Convention

The project uses self-checking SystemVerilog testbenches.

Inputs are generally driven on the falling edge:

```text
drive inputs on negedge
DUT samples inputs on posedge
check outputs after posedge with a small delay
```

This avoids races between the testbench and clocked RTL.

Typical pattern:

```systemverilog
@(negedge clk);
valid = 1'b1;
data  = value;

@(posedge clk);
#1;

valid = 1'b0;
```

State updates use nonblocking assignments. Registered state changes after the rising edge, and combinational outputs then settle based on the new state.

---

## Tools

* SystemVerilog
* Verilator
* GTKWave
* Make
* Linux / Ubuntu
* Git and GitHub

---

## Planned Next Steps

Near-term:

1. Move register-file and rename-table operand selection into a dispatch-stage RTL module.
2. Create a small integrated integer-backend top module.
3. Allow commit to proceed automatically rather than being manually controlled by testbenches.
4. Add additional dependency and WAW integration tests.
5. Improve issue scheduling and cycle-level assertions.

Longer-term:

1. Add multiple functional units and CDB arbitration.
2. Add a load/store queue.
3. Add conservative memory-ordering behavior.
4. Add store-to-load forwarding.
5. Add branch execution and recovery.
6. Add a simple branch predictor.
7. Add a blocking L1 data cache.
8. Compare architectural results against the existing C++ Tomasulo simulator.
9. Add performance counters and trace export.


