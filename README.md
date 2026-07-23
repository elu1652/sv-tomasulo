# SystemVerilog Tomasulo / OoO Processor Project

This project is a staged SystemVerilog implementation of a small Tomasulo-style out-of-order execution backend.

The design is being built incrementally using independently verified RTL modules and a reusable integrated backend.

The main architectural goal is to demonstrate:

```text
out-of-order execution + in-order commit
```

The current design supports tagged dependencies, register renaming, separate ALU and multiply execution paths, reservation-station wakeup, fixed-latency execution, CDB arbitration, result backpressure, ROB-based writeback and commit, and committed architectural register state.

---

## Current Status

Implemented and tested:

* Combinational ALU
* Parameterized architectural register file
* Fixed-latency functional unit with result ready/valid backpressure
* FIFO / circular queue
* Reorder buffer
* Reservation station
* Single-source common data bus
* Two-source fixed-priority CDB arbiter
* Rename table
* Dispatch-stage operand selection and ALU/MUL routing
* Reusable integrated integer backend with a decoded ready/valid dispatch interface
* Separate ALU and multiply reservation stations
* Separate short- and long-latency functional units
* RS → FU → CDB → ROB writeback integration
* Dependency wakeup through CDB tags
* Cross-functional-unit dependency wakeup
* Rename-table and register-file integration
* Out-of-order completion with in-order ROB commit
* Simultaneous FU-result collision handling
* FU result holding under CDB backpressure
* ROB commit into architectural register state
* Automatic one-instruction-per-cycle in-order commit
* Self-checking SystemVerilog testbenches
* Cycle-based event logging
* Verilator simulation and lint workflow
* GTKWave waveform generation

The integrated backend can execute independent instructions such as:

```asm
MUL R1, R2, R3
ADD R4, R5, R6
```

The younger ADD may complete before the older multiply, but the ROB still commits the multiply first.

It also supports dependencies across execution paths:

```asm
MUL R1, R2, R3
ADD R4, R1, R5
```

The ADD waits in the ALU reservation station for the multiply result, wakes when the matching ROB tag is broadcast on the CDB, and then executes.

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

The functional unit uses a ready/valid result handshake.

If the result cannot immediately use the CDB, the FU:

```text
keeps result_valid asserted
holds the result and destination tag stable
remains busy until result_ready is asserted
```

This prevents results from being lost when multiple functional units complete at the same time.

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
Allocate older MUL as ROB0
Allocate younger ADD as ROB1
ROB1 writes back before ROB0
ROB1 cannot commit because ROB0 is still at the head
ROB0 writes back
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

The integrated backend instantiates separate reservation stations for:

```text
ALU operations
multiply operations
```

Oldest-ready scheduling and multi-issue reservation stations remain future extensions.

---

### Common Data Bus

File:

```text
rtl/core/cdb.sv
```

The original CDB module is a combinational tagged broadcast path from one functional unit.

It broadcasts:

```text
valid
ROB destination tag
result value
```

The same broadcast is observed by:

* The ROB for result writeback
* Reservation stations for operand wakeup

This module is still used by the earlier single-FU integration tests.

---

### CDB Arbiter

File:

```text
rtl/core/cdb_arbiter.sv
```

The CDB arbiter accepts completed results from two functional units:

```text
source 0: ALU functional unit
source 1: multiply functional unit
```

It selects one result for the shared CDB.

The current arbitration policy is fixed priority:

```text
ALU has priority over MUL
```

The arbiter also produces a separate `ready` signal for each functional unit.

When both FUs complete simultaneously:

```text
ALU broadcasts first
MUL receives backpressure
MUL holds its result and tag
MUL broadcasts on a later cycle
```

A dedicated integration test verifies that no result is dropped during CDB contention.

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

### Dispatch

File:

```text
rtl/core/dispatch.sv
```

The dispatch module coordinates instruction insertion into the backend.

It:

* Forwards source-register addresses to the register file
* Looks up source dependencies in the rename table
* Converts each source into either a ready value or a waiting ROB tag
* Allocates a new ROB entry
* Updates the destination rename mapping
* Routes ALU operations to the ALU reservation station
* Routes multiply operations to the multiply reservation station
* Applies backpressure if the ROB or selected reservation station is full

Dispatch is atomic:

```text
ROB allocation
rename-table update
reservation-station insertion
```

occur together only when all required structures are ready.

Only the selected reservation station affects `dispatch_ready`.

For example:

```text
a full MUL RS does not block an ADD
a full ALU RS does not block a MUL
```

---

### Reusable Backend

File:

```text
rtl/core/backend.sv
```

The reusable backend integrates:

```text
dispatch
architectural register file
rename table
reorder buffer
ALU reservation station
MUL reservation station
short-latency ALU functional unit
long-latency MUL functional unit
fixed-priority CDB arbiter
ROB writeback
automatic one-instruction-per-cycle in-order commit
register-file commit writes
rename-table commit cleanup
```

It accepts decoded instructions through a ready/valid dispatch interface.

For integration and observation, it exposes:

```text
commit events
ROB occupancy
ALU RS occupancy
MUL RS occupancy
CDB broadcasts
selected FU result handshake debug signals
```

The register file also has a test initialization interface used by the integration testbenches.

This module is a reusable integer out-of-order backend, not a full processor. It does not include a frontend, instruction fetch or decoding, a memory system, branches, or recovery.

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
dispatch
register file
rename table
ROB
ALU reservation station
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

---

### Backend Out-of-Order Integration Test

File:

```text
tb/core/backend_ooo_tb.sv
```

Integrates:

```text
dispatch
register file
rename table
ROB
ALU reservation station
MUL reservation station
ALU functional unit
MUL functional unit
CDB arbiter
```

It executes:

```asm
I0: MUL R1, R2, R3
I1: ADD R4, R5, R6
```

The multiply is older but has a longer latency.

Expected behavior:

```text
MUL receives ROB0
ADD receives ROB1

MUL issues first
ADD issues later but completes first

ROB1 writes back before ROB0
ROB1 cannot commit while ROB0 is incomplete

ROB0 writes back
ROB0 commits
ROB1 commits
```

This proves:

```text
out-of-order completion + in-order commit
```

---

### Cross-FU Dependency Test

File:

```text
tb/core/backend_cross_fu_dependency_tb.sv
```

Verifies dependency wakeup between different execution paths.

It executes:

```asm
I0: MUL R1, R2, R3
I1: ADD R4, R1, R5
```

The ADD is routed to the ALU reservation station but waits for the multiply's ROB tag.

Expected behavior:

```text
MUL executes in the multiply FU
ADD remains waiting in the ALU RS
MUL result broadcasts on the CDB
ALU RS captures the matching result
ADD becomes ready and issues
both instructions commit in program order
```

---

### Manually Wired CDB Collision and Backpressure Test

File:

```text
tb/core/backend_cdb_collision_tb.sv
```

Verifies simultaneous ALU and multiply completion.

The test aligns the FU latencies so both produce `result_valid` in the same cycle.

Expected behavior:

```text
ALU and MUL request the CDB simultaneously
ALU wins fixed-priority arbitration
MUL receives result backpressure
MUL keeps its value and tag stable
MUL broadcasts on the following cycle
both ROB entries receive their results
commit remains in program order
```

This verifies that no result is lost when multiple functional units contend for the shared CDB.

---

### Reusable Backend Basic End-to-End Test

File:

```text
tb/core/backend_basic_tb.sv
```

Executes:

```asm
ADD R1, R2, R3
```

through `backend.sv` and verifies:

```text
dispatch
ROB allocation
ALU RS issue
ALU execution
CDB writeback
ROB commit
architectural register update
```

---

### Reusable Backend Same-FU Dependency Test

File:

```text
tb/core/backend_dependency_top_tb.sv
```

Executes:

```asm
I0: ADD R1, R2, R3
I1: ADD R4, R1, R5
```

and verifies:

```text
rename lookup
waiting ROB tag
ALU RS dependency tracking
CDB wakeup
dependent execution
in-order commit
```

---

### Reusable Backend Out-of-Order Test

File:

```text
tb/core/backend_ooo_top_tb.sv
```

Executes:

```asm
I0: MUL R1, R2, R3
I1: ADD R4, R5, R6
```

The younger ADD completes and writes back before the older multiply, while the ROB still commits the multiply first.

---

### Reusable Backend Cross-FU Dependency Test

File:

```text
tb/core/backend_cross_fu_dependency_top_tb.sv
```

Executes:

```asm
I0: MUL R1, R2, R3
I1: ADD R4, R1, R5
```

The multiply result broadcasts through the shared CDB, wakes the dependent instruction in the ALU reservation station, and both instructions commit in program order.

---

### Reusable Backend CDB Collision and Backpressure Test

File:

```text
tb/core/backend_tb.sv
```

This is the reusable-backend collision test. It verifies:

```text
ALU and MUL results becoming valid simultaneously
fixed-priority arbitration where ALU/source 0 wins
MUL result backpressure
stable held MUL result and tag
MUL broadcast on the next cycle
no dropped results
in-order commit despite CDB ordering
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
│       ├── cdb_arbiter.sv
│       ├── rename_table.sv
│       ├── dispatch.sv
│       └── backend.sv
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
│       ├── cdb_arbiter_tb.sv
│       ├── rename_table_tb.sv
│       ├── dispatch_tb.sv
│       ├── backend_writeback_tb.sv
│       ├── backend_dependency_tb.sv
│       ├── backend_rename_tb.sv
│       ├── backend_ooo_tb.sv
│       ├── backend_cross_fu_dependency_tb.sv
│       ├── backend_cdb_collision_tb.sv
│       ├── backend_basic_tb.sv
│       ├── backend_dependency_top_tb.sv
│       ├── backend_ooo_top_tb.sv
│       ├── backend_cross_fu_dependency_top_tb.sv
│       └── backend_tb.sv
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

This runs both the older standalone and manually wired integration tests and the reusable-backend tests.

Run all lint checks:

```bash
make lint
```

This lints both the older tests and the reusable-backend tests.

Run an individual test:

```bash
make sim_rob
make sim_rs
make sim_cdb
make sim_cdb_arbiter
make sim_rename_table
make sim_dispatch
make sim_backend_writeback
make sim_backend_dependency
make sim_backend_rename
make sim_backend_ooo
make sim_backend_cross_fu_dependency
make sim_backend_cdb_collision
make sim_backend
make sim_backend_basic
make sim_backend_dependency_top
make sim_backend_ooo_top
make sim_backend_cross_fu_dependency_top
```

Open a waveform:

```bash
make wave_rob
make wave_rs
make wave_backend_rename
make wave_backend_ooo
make wave_backend_cross_fu_dependency
make wave_backend_cdb_collision
make wave_backend
make wave_backend_basic
make wave_backend_dependency_top
make wave_backend_ooo_top
make wave_backend_cross_fu_dependency_top
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

1. Add additional dependency, WAW, and same-cycle interaction tests.
2. Improve reservation-station issue scheduling and cycle-level assertions.
3. Replace fixed-priority CDB arbitration with round-robin arbitration.
4. Add reusable instruction and operation definitions in a shared package.

Longer-term:

1. Add a load/store queue.
2. Add conservative memory-ordering behavior.
3. Add store-to-load forwarding.
4. Add branch execution and recovery.
5. Add a simple branch predictor.
6. Add a blocking L1 data cache.
7. Compare architectural results against the existing C++ Tomasulo simulator.
8. Add performance counters and trace export.
