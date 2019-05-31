#include "dray_internal.h"
#include <stdio.h>
#include <time.h>

static double get_time_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1.0e-9;
}

void dray_run_benchmarks(void) {
    printf("\n=== DRAY HIGH-PERFORMANCE MICRO-BENCHMARKS ===\n\n");

    // Create a 50-customer synthetic problem instance
    size_t num_custs = 50;
    dray_problem_t* prob = dray_problem_create();

    dray_depot_t depot = { 0, { 50.0, 50.0 }, { 0.0, 86400.0 } };
    dray_problem_add_depot(prob, &depot);

    for (size_t i = 1; i <= num_custs; i++) {
        double angle = (double)i * 0.1256;
        double radius = 10.0 + (double)(i % 15) * 2.0;
        dray_customer_t c = {
            i,
            { 50.0 + radius * cos(angle), 50.0 + radius * sin(angle) },
            10 + (int64_t)(i % 10),
            { 0.0, 86400.0 },
            300.0
        };
        dray_problem_add_customer(prob, &c);
    }

    for (size_t v = 0; v < 5; v++) {
        dray_vehicle_t veh = { v + 1, 200, 0, 0.0, 86400.0, 100.0, 1.0 };
        dray_problem_add_vehicle(prob, &veh);
    }

    dray_problem_compute_euclidean_matrix(prob);

    // Benchmark 1: Distance matrix lookups
    size_t lookups = 10000000;
    double t0 = get_time_sec();
    double sum = 0.0;
    for (size_t k = 0; k < lookups; k++) {
        uint64_t u = (uint64_t)(k % (num_custs + 1));
        uint64_t v = (uint64_t)((k * 7) % (num_custs + 1));
        sum += dray_get_distance(prob, u, v);
    }
    double t1 = get_time_sec();
    double lookup_rate = (double)lookups / (t1 - t0);
    printf("1. Distance Matrix Lookup:\n");
    printf("   Throughput:  %.2f million lookups/sec (Checksum: %.0f)\n", lookup_rate / 1.0e6, sum);
    printf("   Latency:     %.2f ns/lookup\n\n", ((t1 - t0) / (double)lookups) * 1.0e9);

    // Benchmark 2: Route evaluation throughput
    dray_solution_t* init_sol = dray_solve_quick(prob);
    size_t eval_count = 500000;
    double t2 = get_time_sec();
    for (size_t k = 0; k < eval_count; k++) {
        dray_solution_is_feasible(init_sol);
    }
    double t3 = get_time_sec();
    double eval_rate = (double)eval_count / (t3 - t2);
    printf("2. Route Constraint Verification:\n");
    printf("   Throughput:  %.2f million checks/sec\n", eval_rate / 1.0e6);
    printf("   Latency:     %.2f ns/evaluation\n\n", ((t3 - t2) / (double)eval_count) * 1.0e9);

    // Benchmark 3: Full ALNS optimization throughput
    dray_config_t cfg = dray_default_config();
    cfg.max_iterations = 200;
    double t4 = get_time_sec();
    dray_solution_t* best = dray_solve(prob, &cfg);
    double t5 = get_time_sec();

    double elapsed_ms = (t5 - t4) * 1000.0;
    double iter_rate = (double)cfg.max_iterations / (t5 - t4);

    printf("3. ALNS Optimization Convergence (50 customers, 5 vehicles, 200 iterations):\n");
    printf("   Initial Distance:  %.2f km\n", dray_solution_get_distance(init_sol) / 1000.0);
    printf("   Optimized Distance: %.2f km\n", dray_solution_get_distance(best) / 1000.0);
    printf("   Improvement:        %.2f%%\n",
           (1.0 - dray_solution_get_distance(best) / dray_solution_get_distance(init_sol)) * 100.0);
    printf("   Execution Time:     %.2f ms\n", elapsed_ms);
    printf("   Iteration Rate:     %.0f iterations/sec\n\n", iter_rate);

    dray_solution_free(init_sol);
    dray_solution_free(best);
    dray_problem_free(prob);
}
