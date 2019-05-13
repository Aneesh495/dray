#ifndef DRAY_H
#define DRAY_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct dray_coord {
    double x;
    double y;
} dray_coord_t;

typedef struct dray_time_window {
    double ready;
    double due;
} dray_time_window_t;

typedef struct dray_customer {
    uint64_t id;
    dray_coord_t coord;
    int64_t demand;
    dray_time_window_t window;
    double service_duration;
} dray_customer_t;

typedef struct dray_depot {
    uint64_t id;
    dray_coord_t coord;
    dray_time_window_t window;
} dray_depot_t;

typedef struct dray_vehicle {
    uint64_t id;
    int64_t capacity;
    uint64_t depot_id;
    double earliest_start;
    double latest_end;
    double fixed_cost;
    double distance_cost_per_unit;
} dray_vehicle_t;

typedef struct dray_metrics {
    double total_distance_km;
    double total_duration_hours;
    uint64_t active_vehicle_count;
    double capacity_utilization;
    double total_carbon_kg;
    double average_wait_time_sec;
    uint64_t unassigned_count;
} dray_metrics_t;

typedef struct dray_config {
    uint64_t max_iterations;
    double start_temperature;
    double cooling_rate;
    uint64_t segment_size;
    double decay_rate;
    uint64_t min_destroy;
    uint64_t max_destroy;
    uint64_t seed;
} dray_config_t;

typedef struct dray_problem dray_problem_t;
typedef struct dray_solution dray_solution_t;

dray_config_t dray_default_config(void);

dray_problem_t* dray_problem_create(void);
void dray_problem_free(dray_problem_t* prob);

bool dray_problem_add_depot(dray_problem_t* prob, const dray_depot_t* depot);
bool dray_problem_add_customer(dray_problem_t* prob, const dray_customer_t* customer);
bool dray_problem_add_vehicle(dray_problem_t* prob, const dray_vehicle_t* vehicle);
bool dray_problem_set_matrix(dray_problem_t* prob, size_t dim, const double* dists, const double* times);
bool dray_problem_compute_euclidean_matrix(dray_problem_t* prob);

size_t dray_problem_get_customer_count(const dray_problem_t* prob);
size_t dray_problem_get_depot_count(const dray_problem_t* prob);
size_t dray_problem_get_vehicle_count(const dray_problem_t* prob);

dray_solution_t* dray_solve(const dray_problem_t* prob, const dray_config_t* config);
dray_solution_t* dray_solve_quick(const dray_problem_t* prob);
void dray_solution_free(dray_solution_t* sol);

bool dray_solution_is_feasible(const dray_solution_t* sol);
double dray_solution_get_distance(const dray_solution_t* sol);
double dray_solution_get_cost(const dray_solution_t* sol);
size_t dray_solution_get_route_count(const dray_solution_t* sol);
size_t dray_solution_get_unassigned_count(const dray_solution_t* sol);

size_t dray_solution_get_route_customer_count(const dray_solution_t* sol, size_t route_idx);
uint64_t dray_solution_get_route_customer(const dray_solution_t* sol, size_t route_idx, size_t cust_idx);
double dray_solution_get_route_distance(const dray_solution_t* sol, size_t route_idx);
double dray_solution_get_route_duration(const dray_solution_t* sol, size_t route_idx);
int64_t dray_solution_get_route_load(const dray_solution_t* sol, size_t route_idx);

dray_metrics_t dray_solution_get_metrics(const dray_problem_t* prob, const dray_solution_t* sol);

bool dray_server_start(int port);
void dray_server_stop(void);

#ifdef __cplusplus
}
#endif

#endif /* DRAY_H */
