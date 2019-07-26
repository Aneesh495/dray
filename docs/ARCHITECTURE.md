# Architecture Specification

## 1. System Overview

Dray is a high-performance logistics fleet dispatch, road network routing, and vehicle routing optimization engine engineered in Roc and C. The system solves the Multi-Depot Capacitated Vehicle Routing Problem with Time Windows (MD-VRPTW), supporting heterogeneous fleets, driver shift constraints, and real-time on-demand order insertion.

The architecture separates responsibilities into four cohesive tiers:
1. Pure Functional Algorithmic Core (Roc): Immutable data structures, graph search, k-d trees, and metaheuristic operators.
2. High-Performance Platform Runtime (C): Zero-copy matrix allocations, non-blocking POSIX socket event loops, and ANSI terminal rendering.
3. Language Interoperability Layer: Clean C ABI dynamic library (`libdray`) and type-safe Python SDK (`pydray`).
4. Operational Porcelain: Command-line interface (`bin/dray`) and HTTP REST microservice.

---

## 2. Layered Architecture Diagram

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

## 3. Data Flow and Execution Lifecycle

### Step 1: Problem Ingestion and Normalization
A logistics problem definition comprises:
- Depots: Coordinate locations and operating time windows.
- Customers: Delivery coordinates, cargo demand quantities, ready/due service time windows, and service stop durations.
- Fleet: Vehicle capacities, assigned home depot IDs, shift start/end bounds, and fixed/variable operational costs.

### Step 2: Distance and Time Matrix Resolution
For road networks, Dray executes Contraction Hierarchies (CH) preprocessing. Each road intersection is contracted according to edge difference metrics, generating shortcut edges with witness path verification. Queries run using bidirectional upward Dijkstra to produce the distance matrix in sub-microsecond time.

### Step 3: Initial Solution Construction
Before running metaheuristics, Dray constructs an initial feasible solution using either:
- Clarke-Wright Savings: Computes merging savings $S_{ij} = d(D, i) + d(j, D) - d(i, j)$, sorting pairs in descending order and merging routes subject to capacity and time window constraints.
- Sequential Nearest Addition: Greedily inserts the nearest unassigned customer to the current route tail, opening new vehicle routes as capacity saturates.

### Step 4: Adaptive Large Neighborhood Search (ALNS)
The search proceeds through iterative ruin-and-recreate cycles:
1. Operator Selection: A destroy operator (Random, Worst-cost, Shaw, Route removal) and a repair operator (Greedy, Regret-2, Regret-3) are selected using adaptive roulette-wheel weights.
2. Ruin: The destroy operator extracts $q$ customers from active routes, placing them into an unassigned pool.
3. Recreate: The repair operator re-inserts unassigned customers into optimal feasible positions.
4. Local Search: Fast 2-opt edge exchanges and relocate moves polish the candidate solution.
5. Acceptance: The candidate is evaluated against the current solution using Simulated Annealing with geometric cooling.

### Step 5: Metrics and Telemetry Export
Upon completion, the engine calculates operational KPIs:
- Fleet capacity utilization percentage.
- Total operating duration across all vehicles.
- Carbon footprint estimates (160g CO2 per kilometer).
- Feasibility verification: zero capacity overflow, zero time window violations.
