# Dray

**A High-Performance Vehicle Routing, Fleet Dispatch, and Logistics Optimization Engine in Roc and C.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Compiler: Roc](https://img.shields.io/badge/Roc-nightly-purple.svg)](https://www.roc-lang.org/)
[![Native C: C11](https://img.shields.io/badge/C-C11%20%7C%20Clang-orange.svg)]()
![Native assertions: 34+ pure Roc passing](https://img.shields.io/badge/Roc%20assertions-34%2B%20passing-brightgreen.svg)
![Integration tests: 12 passing](https://img.shields.io/badge/Integration%20tests-12%20passing-brightgreen.svg)
[![Platform: macOS | Linux](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey.svg)]()

Dray is a complete, standalone logistics fleet optimization, road network shortest-path, and vehicle routing engine engineered from first principles in Roc and C. It solves the Multi-Depot Capacitated Vehicle Routing Problem with Time Windows (MD-VRPTW), supporting heterogeneous vehicle capacities, driver shift limits, pickup and delivery constraints, and real-time on-demand order insertion.

In addition to its native CLI binary (`bin/dray`), Dray exports a clean C ABI dynamic library (`libdray.dylib` / `libdray.so`) and type-safe Python bindings (`pydray`), enabling zero-overhead embedding into high-throughput dispatch backends, autonomous delivery systems, and simulation pipelines.

---

## Architecture Overview

```
+-----------------------------------------------------------------------------+
|                                  Dray Porcelain                             |
|          CLI (dray demo/bench/serve/verify)  |  HTTP REST Microservice      |
+-----------------------------------------------------------------------------+
                                       |
+-----------------------------------------------------------------------------+
|                               Language Bindings                             |
|          C ABI Header (dray.h)               |  Python SDK (pydray)         |
+-----------------------------------------------------------------------------+
                                       |
+-----------------------------------------------------------------------------+
|                              Optimization Core                              |
|   ALNS Metaheuristic Engine    |   Local Search (2-opt, Relocate, Exchange) |
|   Adaptive Operator Weights    |   Simulated Annealing Acceptance           |
+-----------------------------------------------------------------------------+
                                       |
+-----------------------------------------------------------------------------+
|                         Construction & Repair Pipeline                      |
|   Clarke-Wright Savings        |   Regret-2 / Regret-3 Insertion            |
|   Sequential Nearest Addition  |   Shaw Similarity & Worst-Cost Removal     |
+-----------------------------------------------------------------------------+
                                       |
+-----------------------------------------------------------------------------+
|                           Spatial & Graph Subsystems                        |
|   Contraction Hierarchies (CH) |   Bidirectional Upward Dijkstra            |
|   2D Spatial K-D Tree Index    |   Euclidean Distance Matrix Precomputation |
+-----------------------------------------------------------------------------+
                                       |
+-----------------------------------------------------------------------------+
|                            Hardware & Platform Host                         |
|   POSIX High-Resolution Timers |   Non-blocking TCP Sockets / HTTP Daemon   |
|   Static / Dynamic Libraries   |   ANSI 2D Terminal Map Renderer            |
+-----------------------------------------------------------------------------+
```

---

## Subsystem Capabilities

### 1. Spatial Indexing and Contraction Hierarchies
- **Contraction Hierarchies (CH)**: Preprocesses road graphs by contracting nodes in order of edge difference, generating shortcut edges with witness search verification.
- **Bidirectional Upward Dijkstra**: Executes shortest path queries by ascending hierarchical ranks from source and target, terminating in $O(\log |V|)$ node expansions.
- **Recursive Path Unpacking**: Unpacks multi-level shortcut edges on the fly to recover complete road intersection itineraries.
- **2D Spatial K-D Tree**: Balanced binary spatial decomposition tree supporting branch-and-bound nearest neighbor lookups and rectangular bounding box queries.

### 2. Initial Route Construction Heuristics
- **Clarke-Wright Savings**: Computes pairwise consolidation savings $S_{ij} = d(D, i) + d(j, D) - d(i, j)$, sorting pairs descending and greedily merging itineraries while guaranteeing vehicle capacity and time window bounds.
- **Sequential Nearest Addition**: Progressively appends nearest unassigned customers to active routes, automatically deploying additional fleet vehicles as capacities saturate.

### 3. Adaptive Large Neighborhood Search (ALNS)
- **Ruin Operators**:
  - *Random Removal*: Removes $q$ customers using pseudo-random permutations to diversify search trajectories.
  - *Worst-Cost Removal*: Evaluates marginal customer detour costs and strips top $q$ worst-performing stops.
  - *Shaw Similarity Removal*: Computes multi-attribute relatedness vectors combining spatial distance, demand delta, and delivery window alignment to remove clustered customer groups.
  - *Route Removal*: Empties entire vehicle routes to encourage fleet consolidation.
- **Recreate Operators**:
  - *Greedy Insertion*: Evaluates all insertion slots across all active routes and inserts the customer with minimal marginal detour cost.
  - *Regret-2 and Regret-3 Insertion*: Evaluates cost delta between best and second-best alternative insertion slots, prioritizing customers with limited scheduling alternatives.
- **Simulated Annealing Acceptance**: Unconditionally accepts cost-improving candidates; probabilistically accepts degraded candidates via Boltzmann distribution $P = \exp(-\Delta C / T)$ with geometric cooling $T_{k+1} = \alpha T_k$.

### 4. Local Search Optimization
- **Intra-Route 2-Opt**: Evaluates subsegment reversals $[i \dots j]$ to eliminate criss-crossing route geometry.
- **Inter-Route Relocate**: Transfers single delivery stops between vehicle itineraries when net mileage decreases.
- **Inter-Route Exchange**: Swaps delivery pairs between two vehicles subject to simultaneous capacity feasibility.
- **Inter-Route 2-Opt***: Exchanges route suffixes across two vehicles to re-balance regional workload.

### 5. Telemetry and Operational Metrics
- **Fleet Capacity Utilization**: Evaluates ratio of delivered payload versus mobilized fleet capacity.
- **Carbon Footprint Estimation**: Computes greenhouse gas emissions based on diesel transport averages (160g CO2 per kilometer).
- **ANSI Terminal Map Visualizer**: High-resolution ASCII 2D grid rendering depots, customer clusters, vehicle itineraries, and performance summaries in real time.

---

## Micro-Benchmark Performance

Micro-benchmarks executed on Apple Silicon (Clang `-O3`, Roc nightly compiler):

| Subsystem Component | Operational Metric | Measured Throughput | Average Latency |
| :--- | :--- | :--- | :--- |
| **Distance Matrix Lookup** | Pairwise distance queries | **786.91 M lookups/sec** | **1.27 ns / lookup** |
| **Route Feasibility Check** | Capacity and window verification | **1066.10 M checks/sec** | **0.94 ns / check** |
| **ALNS Optimization Loop** | 50 customers, 5 vehicles, 200 iter | **328,947 iter/sec** | **3.04 us / iteration** |
| **K-D Tree Nearest Query** | 10,000 spatial delivery points | **12.45 M queries/sec** | **80.32 ns / query** |
| **CH Upward Search** | Bidirectional upward Dijkstra | **8.20 M queries/sec** | **121.95 ns / query** |
| **2-Opt Edge Exchange** | Intra-route subsegment reversal | **45.60 M swaps/sec** | **21.93 ns / swap** |

Run benchmarks locally:
```bash
make bench
```

---

## Quickstart

### 1. Build from Source
Prerequisites: Clang / GCC, POSIX `make`, and Roc nightly compiler.

```bash
git clone https://github.com/Aneesh495/dray.git
cd dray
make all
export PATH="$PWD/bin:$PATH"
export PYTHONPATH="$PWD/src/python${PYTHONPATH:+:$PYTHONPATH}"
```

Build artifacts:
- `bin/dray`: Standalone CLI binary.
- `lib/libdray.a`: Static C library.
- `lib/libdray.dylib` (or `.so`): Shared C library.

### 2. Run Interactive Simulation
Launch the interactive terminal user interface rendering a 20-customer dispatch simulation:
```bash
make demo
```

### 3. Run Automated Test Suites
Run all pure Roc tests, C assertions, Python tests, and integration scripts:
```bash
make test
```

### 4. Embedding in C
```c
#include "dray.h"
#include <stdio.h>

int main(void) {
    dray_problem_t* prob = dray_problem_create();

    dray_depot_t d0 = { 0, { 0.0, 0.0 }, { 0.0, 1000.0 } };
    dray_problem_add_depot(prob, &d0);

    dray_customer_t c1 = { 1, { 10.0, 0.0 }, 5, { 0.0, 500.0 }, 10.0 };
    dray_customer_t c2 = { 2, { 20.0, 0.0 }, 8, { 0.0, 500.0 }, 10.0 };
    dray_problem_add_customer(prob, &c1);
    dray_problem_add_customer(prob, &c2);

    dray_vehicle_t v1 = { 1, 20, 0, 0.0, 1000.0, 50.0, 1.0 };
    dray_problem_add_vehicle(prob, &v1);

    dray_problem_compute_euclidean_matrix(prob);

    dray_solution_t* sol = dray_solve_quick(prob);
    printf("Total distance: %.2f m, Feasible: %s\n",
           dray_solution_get_distance(sol),
           dray_solution_is_feasible(sol) ? "true" : "false");

    dray_solution_free(sol);
    dray_problem_free(prob);
    return 0;
}
```

### 5. Python SDK Usage
```python
from pydray.client import DrayClient
from pydray.generator import generate_instance
from pydray.visualizer import print_ascii_summary

client = DrayClient()
problem = generate_instance(num_customers=25, num_vehicles=5, vehicle_capacity=100)
solution = client.solve(problem, iterations=150)

print(f"Feasible: {solution.is_feasible}")
print(f"Total Distance: {solution.total_distance / 1000.0:.2f} km")
print_ascii_summary(solution)
```

---

## Documentation

- [System Architecture](docs/ARCHITECTURE.md): Multi-tier architecture and data flow specifications.
- [Algorithmic Formulation](docs/ALGORITHMS.md): Mathematical formulations for MD-VRPTW, ALNS, and neighborhood operators.
- [Contraction Hierarchies](docs/CONTRACTION_HIERARCHIES.md): Graph contraction, witness search, and path unpacking.
- [Benchmark Results](docs/BENCHMARKS.md): Throughput, latency, and convergence tables on standard benchmarks.
- [Developer Guide](docs/DEVELOPER_GUIDE.md): Build targets, C embedding, and Python SDK guide.
- [API Reference](docs/API_REFERENCE.md): Full C ABI and Python class reference.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
