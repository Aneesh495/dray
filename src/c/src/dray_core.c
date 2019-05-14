#include "dray_internal.h"
#include <stdio.h>

dray_config_t dray_default_config(void) {
    dray_config_t cfg;
    cfg.max_iterations = 100;
    cfg.start_temperature = 100.0;
    cfg.cooling_rate = 0.98;
    cfg.segment_size = 20;
    cfg.decay_rate = 0.8;
    cfg.min_destroy = 1;
    cfg.max_destroy = 4;
    cfg.seed = 42;
    return cfg;
}

dray_problem_t* dray_problem_create(void) {
    dray_problem_t* p = (dray_problem_t*)calloc(1, sizeof(dray_problem_t));
    if (!p) return NULL;

    p->depot_capacity = 8;
    p->depots = (dray_depot_t*)malloc(p->depot_capacity * sizeof(dray_depot_t));

    p->customer_capacity = 64;
    p->customers = (dray_customer_t*)malloc(p->customer_capacity * sizeof(dray_customer_t));

    p->vehicle_capacity = 16;
    p->vehicles = (dray_vehicle_t*)malloc(p->vehicle_capacity * sizeof(dray_vehicle_t));

    return p;
}

void dray_problem_free(dray_problem_t* prob) {
    if (!prob) return;
    free(prob->depots);
    free(prob->customers);
    free(prob->vehicles);
    free(prob->distances);
    free(prob->travel_times);
    free(prob);
}

bool dray_problem_add_depot(dray_problem_t* prob, const dray_depot_t* depot) {
    if (!prob || !depot) return false;
    if (prob->depot_count >= prob->depot_capacity) {
        size_t new_cap = prob->depot_capacity * 2;
        dray_depot_t* n = (dray_depot_t*)realloc(prob->depots, new_cap * sizeof(dray_depot_t));
        if (!n) return false;
        prob->depots = n;
        prob->depot_capacity = new_cap;
    }
    prob->depots[prob->depot_count++] = *depot;
    return true;
}

bool dray_problem_add_customer(dray_problem_t* prob, const dray_customer_t* customer) {
    if (!prob || !customer) return false;
    if (prob->customer_count >= prob->customer_capacity) {
        size_t new_cap = prob->customer_capacity * 2;
        dray_customer_t* n = (dray_customer_t*)realloc(prob->customers, new_cap * sizeof(dray_customer_t));
        if (!n) return false;
        prob->customers = n;
        prob->customer_capacity = new_cap;
    }
    prob->customers[prob->customer_count++] = *customer;
    return true;
}

bool dray_problem_add_vehicle(dray_problem_t* prob, const dray_vehicle_t* vehicle) {
    if (!prob || !vehicle) return false;
    if (prob->vehicle_count >= prob->vehicle_capacity) {
        size_t new_cap = prob->vehicle_capacity * 2;
        dray_vehicle_t* n = (dray_vehicle_t*)realloc(prob->vehicles, new_cap * sizeof(dray_vehicle_t));
        if (!n) return false;
        prob->vehicles = n;
        prob->vehicle_capacity = new_cap;
    }
    prob->vehicles[prob->vehicle_count++] = *vehicle;
    return true;
}

bool dray_problem_set_matrix(dray_problem_t* prob, size_t dim, const double* dists, const double* times) {
    if (!prob || !dists || !times || dim == 0) return false;

    free(prob->distances);
    free(prob->travel_times);

    size_t sz = dim * dim * sizeof(double);
    prob->distances = (double*)malloc(sz);
    prob->travel_times = (double*)malloc(sz);

    if (!prob->distances || !prob->travel_times) {
        free(prob->distances);
        free(prob->travel_times);
        prob->distances = NULL;
        prob->travel_times = NULL;
        return false;
    }

    memcpy(prob->distances, dists, sz);
    memcpy(prob->travel_times, times, sz);
    prob->matrix_dim = dim;
    return true;
}

bool dray_problem_compute_euclidean_matrix(dray_problem_t* prob) {
    if (!prob) return false;
    size_t total = prob->depot_count + prob->customer_count;
    if (total == 0) return false;

    dray_coord_t* all_coords = (dray_coord_t*)malloc(total * sizeof(dray_coord_t));
    if (!all_coords) return false;

    for (size_t i = 0; i < prob->depot_count; i++) {
        all_coords[prob->depots[i].id] = prob->depots[i].coord;
    }
    for (size_t i = 0; i < prob->customer_count; i++) {
        all_coords[prob->customers[i].id] = prob->customers[i].coord;
    }

    size_t sz = total * total * sizeof(double);
    double* dists = (double*)malloc(sz);
    double* times = (double*)malloc(sz);

    if (!dists || !times) {
        free(all_coords);
        free(dists);
        free(times);
        return false;
    }

    double speed = 15.0; // 15 meters/sec = 54 km/h

    for (size_t i = 0; i < total; i++) {
        for (size_t j = 0; j < total; j++) {
            double dx = all_coords[i].x - all_coords[j].x;
            double dy = all_coords[i].y - all_coords[j].y;
            double d = sqrt(dx * dx + dy * dy);
            dists[i * total + j] = d;
            times[i * total + j] = d / speed;
        }
    }

    free(all_coords);
    return dray_problem_set_matrix(prob, total, dists, times);
}

size_t dray_problem_get_customer_count(const dray_problem_t* prob) {
    return prob ? prob->customer_count : 0;
}

size_t dray_problem_get_depot_count(const dray_problem_t* prob) {
    return prob ? prob->depot_count : 0;
}

size_t dray_problem_get_vehicle_count(const dray_problem_t* prob) {
    return prob ? prob->vehicle_count : 0;
}

double dray_get_distance(const dray_problem_t* prob, uint64_t from_id, uint64_t to_id) {
    if (!prob || !prob->distances || from_id >= prob->matrix_dim || to_id >= prob->matrix_dim) {
        return DRAY_INFINITY;
    }
    return prob->distances[from_id * prob->matrix_dim + to_id];
}

double dray_get_travel_time(const dray_problem_t* prob, uint64_t from_id, uint64_t to_id) {
    if (!prob || !prob->travel_times || from_id >= prob->matrix_dim || to_id >= prob->matrix_dim) {
        return DRAY_INFINITY;
    }
    return prob->travel_times[from_id * prob->matrix_dim + to_id];
}

const dray_customer_t* dray_find_customer(const dray_problem_t* prob, uint64_t id) {
    if (!prob) return NULL;
    for (size_t i = 0; i < prob->customer_count; i++) {
        if (prob->customers[i].id == id) {
            return &prob->customers[i];
        }
    }
    return NULL;
}

void dray_solution_free(dray_solution_t* sol) {
    if (!sol) return;
    for (size_t i = 0; i < sol->route_count; i++) {
        free(sol->routes[i].customers);
    }
    free(sol->routes);
    free(sol->unassigned);
    free(sol);
}

bool dray_solution_is_feasible(const dray_solution_t* sol) {
    return sol ? sol->is_feasible : false;
}

double dray_solution_get_distance(const dray_solution_t* sol) {
    return sol ? sol->total_distance : 0.0;
}

double dray_solution_get_cost(const dray_solution_t* sol) {
    return sol ? sol->total_cost : 0.0;
}

size_t dray_solution_get_route_count(const dray_solution_t* sol) {
    return sol ? sol->route_count : 0;
}

size_t dray_solution_get_unassigned_count(const dray_solution_t* sol) {
    return sol ? sol->unassigned_count : 0;
}

size_t dray_solution_get_route_customer_count(const dray_solution_t* sol, size_t route_idx) {
    if (!sol || route_idx >= sol->route_count) return 0;
    return sol->routes[route_idx].customer_count;
}

uint64_t dray_solution_get_route_customer(const dray_solution_t* sol, size_t route_idx, size_t cust_idx) {
    if (!sol || route_idx >= sol->route_count || cust_idx >= sol->routes[route_idx].customer_count) return 0;
    return sol->routes[route_idx].customers[cust_idx];
}

double dray_solution_get_route_distance(const dray_solution_t* sol, size_t route_idx) {
    if (!sol || route_idx >= sol->route_count) return 0.0;
    return sol->routes[route_idx].distance;
}

double dray_solution_get_route_duration(const dray_solution_t* sol, size_t route_idx) {
    if (!sol || route_idx >= sol->route_count) return 0.0;
    return sol->routes[route_idx].duration;
}

int64_t dray_solution_get_route_load(const dray_solution_t* sol, size_t route_idx) {
    if (!sol || route_idx >= sol->route_count) return 0;
    return sol->routes[route_idx].load;
}

dray_metrics_t dray_solution_get_metrics(const dray_problem_t* prob, const dray_solution_t* sol) {
    dray_metrics_t m;
    memset(&m, 0, sizeof(m));
    if (!prob || !sol) return m;

    m.total_distance_km = sol->total_distance / 1000.0;

    double total_sec = 0.0;
    uint64_t active_count = 0;
    int64_t total_carried = 0;
    int64_t total_cap = 0;

    for (size_t i = 0; i < sol->route_count; i++) {
        if (sol->routes[i].customer_count > 0) {
            active_count++;
            total_sec += sol->routes[i].duration;
            total_carried += sol->routes[i].load;
            if (i < prob->vehicle_count) {
                total_cap += prob->vehicles[i].capacity;
            }
        }
    }

    m.total_duration_hours = total_sec / 3600.0;
    m.active_vehicle_count = active_count;
    m.capacity_utilization = (total_cap > 0) ? ((double)total_carried / (double)total_cap) : 0.0;
    m.total_carbon_kg = (m.total_distance_km * 160.0) / 1000.0; // 160g CO2/km
    m.unassigned_count = sol->unassigned_count;

    return m;
}
