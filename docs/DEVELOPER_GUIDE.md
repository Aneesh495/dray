# Developer Guide

## 1. Prerequisites

To build, test, and run Dray from source:
- C Compiler: Apple Clang or GCC supporting C11 and POSIX standards.
- Build Tool: POSIX `make`.
- Roc Compiler: Nightly pre-release compiler from `roc-lang.org`.
- Python (optional): Python 3.9+ for the `pydray` SDK.

---

## 2. Building from Source

Build the complete C runtime, shared library, and CLI binary:
```bash
make all
```

Build outputs:
- `bin/dray`: Standalone CLI executable.
- `lib/libdray.a`: Static library for C/C++ linking.
- `lib/libdray.dylib` (or `.so`): Dynamic shared library for FFI embedding.

---

## 3. Running Test Suites

Run the full automated test suite:
```bash
make test
```

This target executes:
1. Prohibited dash linter (`scripts/lint_dashes.sh`).
2. Pure Roc compiler test runner (`roc test src/roc/Tests.roc`).
3. C native assertion pass (`bin/dray verify`).
4. Micro-benchmark execution (`bin/dray bench`).
5. Python SDK unit and integration tests (`python3 -m unittest discover`).
6. Shell integration test scripts (`tests/integration/*.sh`).

---

## 4. Embedding via C ABI

Include `dray.h` and link against `libdray`:

```c
#include "dray.h"
#include <stdio.h>

int main(void) {
    dray_problem_t* prob = dray_problem_create();

    dray_depot_t d0 = { 0, { 0.0, 0.0 }, { 0.0, 1000.0 } };
    dray_problem_add_depot(prob, &d0);

    dray_customer_t c1 = { 1, { 10.0, 0.0 }, 5, { 0.0, 500.0 }, 10.0 };
    dray_problem_add_customer(prob, &c1);

    dray_vehicle_t v1 = { 1, 20, 0, 0.0, 1000.0, 50.0, 1.0 };
    dray_problem_add_vehicle(prob, &v1);

    dray_problem_compute_euclidean_matrix(prob);

    dray_solution_t* sol = dray_solve_quick(prob);
    printf("Total Distance: %.2f m\n", dray_solution_get_distance(sol));

    dray_solution_free(sol);
    dray_problem_free(prob);
    return 0;
}
```

Compile with:
```bash
clang -O3 example.c -Isrc/c/include -Llib -ldray -lm -o example
```

---

## 5. Python SDK Usage

Install or point `PYTHONPATH` to `src/python`:

```python
from pydray.models import Coord, TimeWindow, Customer, Depot, Vehicle, Problem
from pydray.client import DrayClient

client = DrayClient()

depot = Depot(id=0, coord=Coord(0.0, 0.0), window=TimeWindow(0.0, 1000.0))
customer = Customer(id=1, coord=Coord(5.0, 0.0), demand=5, window=TimeWindow(0.0, 500.0), service_duration=10.0)
vehicle = Vehicle(id=1, capacity=20, depot_id=0, earliest_start=0.0, latest_end=1000.0)

prob = Problem(depots=[depot], customers=[customer], fleet=[vehicle])
solution = client.solve(prob, iterations=50)

print(f"Feasible: {solution.is_feasible}")
print(f"Total Distance: {solution.total_distance / 1000.0:.2f} km")
```
