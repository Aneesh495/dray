#ifndef DRAY_INTERNAL_H
#define DRAY_INTERNAL_H

#include "dray.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define DRAY_MAX_DEPOTS 32
#define DRAY_MAX_CUSTOMERS 4096
#define DRAY_MAX_VEHICLES 512
#define DRAY_INFINITY 1.0e15

typedef struct dray_route_internal {
    uint64_t vehicle_id;
    uint64_t depot_id;
    uint64_t* customers;
    size_t customer_count;
    double distance;
    double duration;
    int64_t load;
    int64_t capacity_excess;
    double time_lateness;
    bool is_feasible;
} dray_route_internal_t;

struct dray_problem {
    dray_depot_t* depots;
    size_t depot_count;
    size_t depot_capacity;

    dray_customer_t* customers;
    size_t customer_count;
    size_t customer_capacity;

    dray_vehicle_t* vehicles;
    size_t vehicle_count;
    size_t vehicle_capacity;

    size_t matrix_dim;
    double* distances;
    double* travel_times;
};

struct dray_solution {
    dray_route_internal_t* routes;
    size_t route_count;

    uint64_t* unassigned;
    size_t unassigned_count;

    double total_distance;
    double total_cost;
    bool is_feasible;
};

double dray_get_distance(const dray_problem_t* prob, uint64_t from_id, uint64_t to_id);
double dray_get_travel_time(const dray_problem_t* prob, uint64_t from_id, uint64_t to_id);
const dray_customer_t* dray_find_customer(const dray_problem_t* prob, uint64_t id);

#endif /* DRAY_INTERNAL_H */
