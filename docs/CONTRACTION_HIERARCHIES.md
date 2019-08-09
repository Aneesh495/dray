# Contraction Hierarchies Specification

## 1. Overview

Contraction Hierarchies (CH) is a preprocessing-based shortest path speedup technique for road networks. On standard continental-scale road networks, traditional Dijkstra requires hundreds of milliseconds to explore millions of nodes. Contraction Hierarchies compresses query time down to microseconds while guaranteeing mathematically exact shortest paths.

Dray implements an end-to-end Contraction Hierarchies engine in pure Roc with a native C fastpath.

---

## 2. Preprocessing: Node Contraction

### 2.1 Contraction Mechanism
When a node $v$ is contracted, it is removed from the network. To preserve shortest path distances between remaining nodes, shortcut edges are added.

For every incoming neighbor $u$ ($u \to v$) and outgoing neighbor $w$ ($v \to w$):
1. Compute the path weight via $v$:
   $$W(u \to v \to w) = \text{weight}(u, v) + \text{weight}(v, w)$$
2. Execute a local witness search: Run Dijkstra from $u$ without allowing traversal through $v$.
3. If the witness path distance $d_{G \setminus \{v\}}(u, w) > W(u \to v \to w)$, then $u \to v \to w$ is the unique shortest path.
4. Add shortcut edge $(u, w)$ with weight $W(u \to v \to w)$, storing $v$ as `bypassedNode`.

### 2.2 Node Ordering Heuristics
Nodes are ordered for contraction based on an importance priority queue:
$$\text{Priority}(v) = \text{EdgeDifference}(v) + \text{ContractedNeighbors}(v)$$

Where:
- $\text{EdgeDifference}(v) = \text{ShortcutsNeeded}(v) - \text{IncidentEdges}(v)$
Nodes whose removal produces few shortcuts are contracted first (e.g., dead ends, residential streets), leaving high-level arterial highways for later contraction.

---

## 3. Query Phase: Bidirectional Upward Search

Each node $u$ is assigned a rank according to its position in the contraction sequence:
$$\text{Rank}(u) \in \{0, 1, \dots, |V| - 1\}$$

The query graph contains:
- Upward Forward Graph $\vec{G}^{\uparrow}$: Forward edges $(u, v)$ where $\text{Rank}(u) < \text{Rank}(v)$.
- Upward Backward Graph $\overleftarrow{G}^{\uparrow}$: Reverse edges $(w, v)$ where $\text{Rank}(w) < \text{Rank}(v)$.

### Query Algorithm
1. Initialize forward Dijkstra from source $s$ exploring only $\vec{G}^{\uparrow}$.
2. Initialize backward Dijkstra from target $t$ exploring only $\overleftarrow{G}^{\uparrow}$.
3. When search frontiers intersect, track the candidate shortest distance:
   $$\mu = \min_{v \in \text{visited}} \left( d_f(v) + d_b(v) \right)$$
4. Terminate when the minimum key in both priority queues satisfies:
   $$\min(\text{PQ}_f) + \min(\text{PQ}_b) \ge \mu$$

Because both search frontiers only climb up the hierarchy, the number of settled nodes is bounded by $O(\log |V|)$ rather than $O(|V|)$.

---

## 4. Recursive Path Unpacking

Shortcut edges in the result path are unpacked recursively to recover the full original sequence of road intersections:

```
unpackPath(u, v):
  if edge(u, v) is not a shortcut:
    return [u, v]
  else:
    mid = edge(u, v).bypassedNode
    leftPath = unpackPath(u, mid)
    rightPath = unpackPath(mid, v)
    return concat(leftPath, rightPath[1:])
```
