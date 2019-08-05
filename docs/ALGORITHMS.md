# Algorithmic Specification

This document details the mathematical formulation and algorithmic mechanics implemented in the Dray optimization engine.

---

## 1. Problem Formulation: MD-VRPTW

The Multi-Depot Capacitated Vehicle Routing Problem with Time Windows (MD-VRPTW) is defined over a directed graph $G = (V, E)$.

The vertex set $V = D \cup C$ partitions into:
- $D = \{d_1, d_2, \dots, d_m\}$: Depots with operating windows $[e_d, l_d]$.
- $C = \{c_1, c_2, \dots, c_n\}$: Customers with cargo demand $q_i > 0$, service duration $s_i$, and delivery windows $[e_i, l_i]$.

The edge set $E$ provides travel distances $d_{ij}$ and travel times $t_{ij}$.
A fleet $K$ of heterogeneous vehicles with capacity $Q_k$ is distributed across depots.

### Objective Function
Minimize total operational cost:
$$\min \sum_{k \in K} \left( F_k \cdot y_k + c_k \sum_{(i,j) \in E} d_{ij} x_{ijk} \right) + P_{cap} \sum_{k \in K} \Omega_k^{cap} + P_{time} \sum_{k \in K} \Omega_k^{time}$$

Where:
- $y_k \in \{0, 1\}$ indicates whether vehicle $k$ is deployed.
- $F_k$ is the vehicle fixed mobilization cost.
- $c_k$ is the variable cost per distance unit.
- $\Omega_k^{cap} = \max(0, \text{Load}_k - Q_k)$ is capacity violation penalty.
- $\Omega_k^{time} = \sum_{i} \max(0, a_{ik} - l_i)$ is arrival lateness penalty.

---

## 2. Construction Heuristics

### 2.1 Clarke-Wright Savings Heuristic
The savings metric represents the distance saved by servicing two customers $i$ and $j$ sequentially on one route rather than two dedicated back-and-forth trips from depot $D$:
$$S_{ij} = d(D, i) + d(j, D) - d(i, j)$$

Algorithm:
1. Initialize each customer $i$ on an isolated route $(D, i, D)$.
2. Compute savings $S_{ij}$ for all pairs and sort descending.
3. Merge route ending in $i$ with route starting with $j$ if merged route satisfies capacity and time window bounds.

### 2.2 Sequential Nearest Addition
Iteratively extends the current vehicle itinerary by selecting the unassigned customer $u^*$ that minimizes incremental travel distance:
$$u^* = \arg\min_{u \in U} d(\text{tail}, u) \quad \text{subject to feasibility}$$

When no customer can be feasibly appended, the route returns to the depot, and a new vehicle is mobilized.

---

## 3. Destroy Operators (Ruin Phase)

### 3.1 Random Removal
Randomly selects $q$ customers using a deterministic pseudo-random sequence to promote exploration of diverse topological configurations.

### 3.2 Worst-Cost Removal
Identifies customers whose inclusion contributes disproportionate travel distance.
For customer $i$ flanked by $p(i)$ and $s(i)$, the cost delta is:
$$\Delta_i = d(p(i), i) + d(i, s(i)) - d(p(i), s(i))$$
Customers are sorted by $\Delta_i$ descending, and the top $q$ elements are removed.

### 3.3 Shaw Similarity Removal
Removes clusters of related customers based on spatial distance, demand magnitude, and time window alignment:
$$R(i, j) = \phi_1 \frac{d(i, j)}{\max d} + \phi_2 \frac{|q_i - q_j|}{\max q} + \phi_3 \frac{|e_i - e_j|}{\max e}$$
Given a pivot customer $i^*$, customers with minimal $R(i^*, j)$ are preferentially removed.

### 3.4 Route Removal
Selects an entire vehicle route and empties all its customer assignments, incentivizing the engine to compress stops into fewer vehicles.

---

## 4. Repair Operators (Recreate Phase)

### 4.1 Greedy Insertion
For each unassigned customer, searches all insertion positions across all routes to locate the move with minimal marginal distance:
$$\Delta c(i, r, p) = d(\text{prev}, i) + d(i, \text{next}) - d(\text{prev}, \text{next})$$
Inserts the customer yielding the globally lowest feasible $\Delta c$.

### 4.2 Regret-k Insertion
Addresses the myopic nature of greedy insertion. For customer $i$, let $c_{i,1} \le c_{i,2} \le \dots \le c_{i,k}$ denote the sorted insertion costs into its $k$ best available routes.
The regret value is:
$$\text{Regret}_k(i) = \sum_{j=2}^k (c_{i,j} - c_{i,1})$$
The customer with the maximum regret is prioritized for insertion, ensuring customers with limited alternative options are scheduled first.

---

## 5. Local Search Operators

1. Intra-Route 2-Opt: Reverses customer subsegments $[i \dots j]$ to eliminate intersecting travel paths.
2. Inter-Route Relocate: Transfers customer $c$ from route $R_1$ into position $p$ in route $R_2$ when net distance decreases.
3. Inter-Route Exchange: Swaps customer $c_1 \in R_1$ with customer $c_2 \in R_2$.
4. Inter-Route 2-Opt*: Swaps the suffix of route $R_1$ after position $i$ with the suffix of route $R_2$ after position $j$.

---

## 6. Simulated Annealing Acceptance

Candidate solutions with lower cost are unconditionally accepted:
$$\Delta C = C(\text{candidate}) - C(\text{current}) < 0 \implies \text{Accept}$$

Degraded solutions ($\Delta C \ge 0$) are accepted with Boltzmann probability:
$$P(\text{Accept}) = \exp\left(-\frac{\Delta C}{T}\right)$$

Temperature cools geometrically across iterations:
$$T_{k+1} = \alpha \cdot T_k \quad (\alpha \in [0.90, 0.99])$$
