#include "dray_internal.h"
#include <stdio.h>
#include <time.h>

static void evaluate_route_c(const dray_problem_t* prob, const dray_vehicle_t* veh, dray_route_internal_t* route) {
    uint64_t depot_id = veh->depot_id;
    double cur_time = veh->earliest_start;
    int64_t cur_load = 0;
    double total_dist = 0.0;
    double total_late = 0.0;
    int64_t cap_excess = 0;

    uint64_t prev = depot_id;

    for (size_t i = 0; i < route->customer_count; i++) {
        uint64_t cid = route->customers[i];
        double d = dray_get_distance(prob, prev, cid);
        double t = dray_get_travel_time(prob, prev, cid);

        double arr = cur_time + t;
        total_dist += d;

        const dray_customer_t* cust = dray_find_customer(prob, cid);
        if (cust) {
            double start = (arr < cust->window.ready) ? cust->window.ready : arr;
            if (arr > cust->window.due) {
                total_late += (arr - cust->window.due);
            }
            cur_time = start + cust->service_duration;
            cur_load += cust->demand;
            if (cur_load > veh->capacity) {
                cap_excess = cur_load - veh->capacity;
            }
        }
        prev = cid;
    }

    double return_d = dray_get_distance(prob, prev, depot_id);
    double return_t = dray_get_travel_time(prob, prev, depot_id);
    double finish = cur_time + return_t;
    total_dist += return_d;

    if (finish > veh->latest_end) {
        total_late += (finish - veh->latest_end);
    }

    route->vehicle_id = veh->id;
    route->depot_id = depot_id;
    route->distance = total_dist;
    route->duration = finish - veh->earliest_start;
    route->load = cur_load;
    route->capacity_excess = cap_excess;
    route->time_lateness = total_late;
    route->is_feasible = (cap_excess == 0) && (total_late <= 0.001);
}

static void evaluate_solution_c(const dray_problem_t* prob, dray_solution_t* sol) {
    double total_dist = 0.0;
    double total_cost = 0.0;
    bool all_feasible = true;

    for (size_t i = 0; i < sol->route_count; i++) {
        dray_vehicle_t fallback = { i, 1000, 0, 0.0, 86400.0, 50.0, 1.0 };
        const dray_vehicle_t* veh = (i < prob->vehicle_count) ? &prob->vehicles[i] : &fallback;

        evaluate_route_c(prob, veh, &sol->routes[i]);

        total_dist += sol->routes[i].distance;
        double fixed = (sol->routes[i].customer_count > 0) ? veh->fixed_cost : 0.0;
        double d_cost = sol->routes[i].distance * veh->distance_cost_per_unit;
        double cap_penalty = (double)sol->routes[i].capacity_excess * 1000.0;
        double late_penalty = sol->routes[i].time_lateness * 100.0;

        total_cost += (fixed + d_cost + cap_penalty + late_penalty);
        if (!sol->routes[i].is_feasible) {
            all_feasible = false;
        }
    }

    total_cost += (double)sol->unassigned_count * 10000.0;
    if (sol->unassigned_count > 0) {
        all_feasible = false;
    }

    sol->total_distance = total_dist;
    sol->total_cost = total_cost;
    sol->is_feasible = all_feasible;
}

static dray_solution_t* create_empty_solution(size_t route_count) {
    dray_solution_t* sol = (dray_solution_t*)calloc(1, sizeof(dray_solution_t));
    if (!sol) return NULL;

    sol->route_count = route_count;
    sol->routes = (dray_route_internal_t*)calloc(route_count, sizeof(dray_route_internal_t));
    return sol;
}

static dray_solution_t* copy_solution(const dray_solution_t* src) {
    if (!src) return NULL;
    dray_solution_t* dst = create_empty_solution(src->route_count);
    if (!dst) return NULL;

    for (size_t i = 0; i < src->route_count; i++) {
        dst->routes[i] = src->routes[i];
        if (src->routes[i].customer_count > 0 && src->routes[i].customers) {
            dst->routes[i].customers = (uint64_t*)malloc(src->routes[i].customer_count * sizeof(uint64_t));
            memcpy(dst->routes[i].customers, src->routes[i].customers, src->routes[i].customer_count * sizeof(uint64_t));
        } else {
            dst->routes[i].customers = NULL;
            dst->routes[i].customer_count = 0;
        }
    }

    if (src->unassigned_count > 0 && src->unassigned) {
        dst->unassigned_count = src->unassigned_count;
        dst->unassigned = (uint64_t*)malloc(src->unassigned_count * sizeof(uint64_t));
        memcpy(dst->unassigned, src->unassigned, src->unassigned_count * sizeof(uint64_t));
    } else {
        dst->unassigned = NULL;
        dst->unassigned_count = 0;
    }

    dst->total_distance = src->total_distance;
    dst->total_cost = src->total_cost;
    dst->is_feasible = src->is_feasible;
    return dst;
}

// Initial constructive heuristic: Nearest Addition
static dray_solution_t* construct_initial_solution(const dray_problem_t* prob) {
    size_t num_custs = prob->customer_count;
    size_t num_vehs = prob->vehicle_count > 0 ? prob->vehicle_count : 1;

    dray_solution_t* sol = create_empty_solution(num_vehs);
    if (!sol) return NULL;

    bool* assigned = (bool*)calloc(num_custs, sizeof(bool));
    if (!assigned) return sol;

    for (size_t v = 0; v < num_vehs; v++) {
        const dray_vehicle_t* veh = &prob->vehicles[v];
        uint64_t last = veh->depot_id;

        uint64_t* route_custs = (uint64_t*)malloc((num_custs + 1) * sizeof(uint64_t));
        size_t r_count = 0;

        while (true) {
            uint64_t best_c = (uint64_t)-1;
            double best_dist = DRAY_INFINITY;

            for (size_t c = 0; c < num_custs; c++) {
                if (!assigned[c]) {
                    uint64_t cid = prob->customers[c].id;
                    double d = dray_get_distance(prob, last, cid);

                    // Test feasibility
                    route_custs[r_count] = cid;
                    dray_route_internal_t test_route;
                    memset(&test_route, 0, sizeof(test_route));
                    test_route.customers = route_custs;
                    test_route.customer_count = r_count + 1;
                    evaluate_route_c(prob, veh, &test_route);

                    if (test_route.is_feasible && d < best_dist) {
                        best_dist = d;
                        best_c = c;
                    }
                }
            }

            if (best_c != (uint64_t)-1) {
                route_custs[r_count++] = prob->customers[best_c].id;
                assigned[best_c] = true;
                last = prob->customers[best_c].id;
            } else {
                break;
            }
        }

        if (r_count > 0) {
            sol->routes[v].customers = (uint64_t*)malloc(r_count * sizeof(uint64_t));
            memcpy(sol->routes[v].customers, route_custs, r_count * sizeof(uint64_t));
            sol->routes[v].customer_count = r_count;
        } else {
            sol->routes[v].customers = NULL;
            sol->routes[v].customer_count = 0;
        }
        free(route_custs);
    }

    // Check unassigned
    size_t unassigned_count = 0;
    for (size_t c = 0; c < num_custs; c++) {
        if (!assigned[c]) unassigned_count++;
    }

    if (unassigned_count > 0) {
        sol->unassigned = (uint64_t*)malloc(unassigned_count * sizeof(uint64_t));
        size_t u_idx = 0;
        for (size_t c = 0; c < num_custs; c++) {
            if (!assigned[c]) {
                sol->unassigned[u_idx++] = prob->customers[c].id;
            }
        }
        sol->unassigned_count = unassigned_count;
    } else {
        sol->unassigned = NULL;
        sol->unassigned_count = 0;
    }

    free(assigned);
    evaluate_solution_c(prob, sol);
    return sol;
}

// 2-opt intra-route improvement
static void two_opt_route(const dray_problem_t* prob, const dray_vehicle_t* veh, dray_route_internal_t* route) {
    if (route->customer_count < 4 || !route->customers) return;
    bool improved = true;

    while (improved) {
        improved = false;
        double best_dist = route->distance;

        for (size_t i = 0; i < route->customer_count - 1; i++) {
            for (size_t j = i + 1; j < route->customer_count; j++) {
                // Reverse subsegment i..j
                for (size_t left = i, right = j; left < right; left++, right--) {
                    uint64_t tmp = route->customers[left];
                    route->customers[left] = route->customers[right];
                    route->customers[right] = tmp;
                }

                evaluate_route_c(prob, veh, route);
                if (route->is_feasible && route->distance < best_dist - 0.001) {
                    best_dist = route->distance;
                    improved = true;
                } else {
                    // Revert
                    for (size_t left = i, right = j; left < right; left++, right--) {
                        uint64_t tmp = route->customers[left];
                        route->customers[left] = route->customers[right];
                        route->customers[right] = tmp;
                    }
                    evaluate_route_c(prob, veh, route);
                }
            }
        }
    }
}

dray_solution_t* dray_solve(const dray_problem_t* prob, const dray_config_t* config) {
    if (!prob) return NULL;

    dray_config_t cfg = config ? *config : dray_default_config();
    dray_solution_t* current = construct_initial_solution(prob);
    if (!current) return NULL;

    // Apply 2-opt to initial solution
    for (size_t i = 0; i < current->route_count; i++) {
        const dray_vehicle_t* veh = (i < prob->vehicle_count) ? &prob->vehicles[i] : &prob->vehicles[0];
        two_opt_route(prob, veh, &current->routes[i]);
    }
    evaluate_solution_c(prob, current);

    dray_solution_t* best = copy_solution(current);
    double temp = cfg.start_temperature;
    uint64_t rng = cfg.seed;

    for (size_t iter = 0; iter < cfg.max_iterations; iter++) {
        dray_solution_t* candidate = copy_solution(current);
        if (!candidate) break;

        // Perturb candidate: pick a customer and relocate to a random position
        if (candidate->route_count > 0) {
            rng = (rng * 1103515245 + 12345) % 2147483648;
            size_t r1 = rng % candidate->route_count;

            if (candidate->routes[r1].customer_count > 0) {
                size_t p1 = (rng / 7) % candidate->routes[r1].customer_count;
                uint64_t cust_to_move = candidate->routes[r1].customers[p1];

                // Remove from r1
                for (size_t k = p1; k < candidate->routes[r1].customer_count - 1; k++) {
                    candidate->routes[r1].customers[k] = candidate->routes[r1].customers[k + 1];
                }
                candidate->routes[r1].customer_count--;

                // Insert into r2
                size_t r2 = (rng / 13) % candidate->route_count;
                size_t p2 = (candidate->routes[r2].customer_count == 0) ? 0 : (rng / 19) % (candidate->routes[r2].customer_count + 1);

                uint64_t* new_r2_custs = (uint64_t*)malloc((candidate->routes[r2].customer_count + 1) * sizeof(uint64_t));
                for (size_t k = 0; k < p2; k++) {
                    new_r2_custs[k] = candidate->routes[r2].customers[k];
                }
                new_r2_custs[p2] = cust_to_move;
                for (size_t k = p2; k < candidate->routes[r2].customer_count; k++) {
                    new_r2_custs[k + 1] = candidate->routes[r2].customers[k];
                }

                free(candidate->routes[r2].customers);
                candidate->routes[r2].customers = new_r2_custs;
                candidate->routes[r2].customer_count++;

                evaluate_solution_c(prob, candidate);

                // Simulated annealing acceptance
                double delta = candidate->total_cost - current->total_cost;
                bool accept = false;

                if (delta < 0.0) {
                    accept = true;
                } else {
                    double prob_acc = exp(-delta / (temp > 0.001 ? temp : 0.001));
                    rng = (rng * 1103515245 + 12345) % 2147483648;
                    double u = (double)rng / 2147483648.0;
                    if (u < prob_acc) accept = true;
                }

                if (accept) {
                    dray_solution_free(current);
                    current = copy_solution(candidate);
                }

                if (candidate->is_feasible && candidate->total_cost < best->total_cost) {
                    dray_solution_free(best);
                    best = copy_solution(candidate);
                }
            }
        }

        dray_solution_free(candidate);
        temp *= cfg.cooling_rate;
    }

    dray_solution_free(current);

    // Final 2-opt pass on best
    for (size_t i = 0; i < best->route_count; i++) {
        const dray_vehicle_t* veh = (i < prob->vehicle_count) ? &prob->vehicles[i] : &prob->vehicles[0];
        two_opt_route(prob, veh, &best->routes[i]);
    }
    evaluate_solution_c(prob, best);

    return best;
}

dray_solution_t* dray_solve_quick(const dray_problem_t* prob) {
    dray_config_t cfg = dray_default_config();
    cfg.max_iterations = 20;
    return dray_solve(prob, &cfg);
}
