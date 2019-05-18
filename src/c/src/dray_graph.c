#include "dray_internal.h"
#include <stdio.h>

typedef struct ch_edge {
    uint64_t target;
    double weight;
    double distance;
    bool is_shortcut;
    uint64_t bypassed_node;
} ch_edge_t;

typedef struct ch_graph {
    size_t node_count;
    ch_edge_t** fwd_edges;
    size_t* fwd_counts;
    size_t* fwd_caps;

    ch_edge_t** rev_edges;
    size_t* rev_counts;
    size_t* rev_caps;

    uint64_t* ranks;
} ch_graph_t;

ch_graph_t* ch_graph_create(size_t nodes) {
    ch_graph_t* g = (ch_graph_t*)calloc(1, sizeof(ch_graph_t));
    if (!g) return NULL;

    g->node_count = nodes;
    g->fwd_edges = (ch_edge_t**)calloc(nodes, sizeof(ch_edge_t*));
    g->fwd_counts = (size_t*)calloc(nodes, sizeof(size_t));
    g->fwd_caps = (size_t*)calloc(nodes, sizeof(size_t));

    g->rev_edges = (ch_edge_t**)calloc(nodes, sizeof(ch_edge_t*));
    g->rev_counts = (size_t*)calloc(nodes, sizeof(size_t));
    g->rev_caps = (size_t*)calloc(nodes, sizeof(size_t));

    g->ranks = (uint64_t*)calloc(nodes, sizeof(uint64_t));
    for (size_t i = 0; i < nodes; i++) {
        g->ranks[i] = i;
    }
    return g;
}

void ch_graph_free(ch_graph_t* g) {
    if (!g) return;
    for (size_t i = 0; i < g->node_count; i++) {
        free(g->fwd_edges[i]);
        free(g->rev_edges[i]);
    }
    free(g->fwd_edges);
    free(g->fwd_counts);
    free(g->fwd_caps);
    free(g->rev_edges);
    free(g->rev_counts);
    free(g->rev_caps);
    free(g->ranks);
    free(g);
}

bool ch_graph_add_edge(ch_graph_t* g, uint64_t u, uint64_t v, double weight, double dist, bool is_shortcut, uint64_t bypassed) {
    if (!g || u >= g->node_count || v >= g->node_count) return false;

    // Add forward edge u -> v
    if (g->fwd_counts[u] >= g->fwd_caps[u]) {
        size_t new_cap = g->fwd_caps[u] == 0 ? 4 : g->fwd_caps[u] * 2;
        ch_edge_t* ne = (ch_edge_t*)realloc(g->fwd_edges[u], new_cap * sizeof(ch_edge_t));
        if (!ne) return false;
        g->fwd_edges[u] = ne;
        g->fwd_caps[u] = new_cap;
    }
    ch_edge_t ef = { v, weight, dist, is_shortcut, bypassed };
    g->fwd_edges[u][g->fwd_counts[u]++] = ef;

    // Add reverse edge v -> u
    if (g->rev_counts[v] >= g->rev_caps[v]) {
        size_t new_cap = g->rev_caps[v] == 0 ? 4 : g->rev_caps[v] * 2;
        ch_edge_t* ne = (ch_edge_t*)realloc(g->rev_edges[v], new_cap * sizeof(ch_edge_t));
        if (!ne) return false;
        g->rev_edges[v] = ne;
        g->rev_caps[v] = new_cap;
    }
    ch_edge_t er = { u, weight, dist, is_shortcut, bypassed };
    g->rev_edges[v][g->rev_counts[v]++] = er;

    return true;
}

// Single-source Dijkstra for distance row computation
void ch_dijkstra_row(const ch_graph_t* g, uint64_t source, double* out_dists) {
    size_t n = g->node_count;
    for (size_t i = 0; i < n; i++) {
        out_dists[i] = DRAY_INFINITY;
    }
    out_dists[source] = 0.0;

    bool* visited = (bool*)calloc(n, sizeof(bool));
    if (!visited) return;

    for (size_t step = 0; step < n; step++) {
        uint64_t u = (uint64_t)-1;
        double min_d = DRAY_INFINITY;

        for (size_t i = 0; i < n; i++) {
            if (!visited[i] && out_dists[i] < min_d) {
                min_d = out_dists[i];
                u = i;
            }
        }

        if (u == (uint64_t)-1 || min_d >= DRAY_INFINITY / 2.0) break;
        visited[u] = true;

        for (size_t e = 0; e < g->fwd_counts[u]; e++) {
            ch_edge_t edge = g->fwd_edges[u][e];
            uint64_t v = edge.target;
            if (!visited[v]) {
                double new_cost = out_dists[u] + edge.weight;
                if (new_cost < out_dists[v]) {
                    out_dists[v] = new_cost;
                }
            }
        }
    }

    free(visited);
}

// Compute full all-pairs distance matrix from road graph
bool ch_compute_all_pairs_matrix(const ch_graph_t* g, double* out_matrix) {
    if (!g || !out_matrix) return false;
    size_t n = g->node_count;
    for (size_t i = 0; i < n; i++) {
        ch_dijkstra_row(g, i, &out_matrix[i * n]);
    }
    return true;
}
