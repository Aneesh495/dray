#include "dray.h"
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    printf("=== DRAY EMBEDDED C CLIENT EXAMPLE ===\n\n");

    dray_problem_t* prob = dray_problem_create();
    if (!prob) {
        fprintf(stderr, "Failed to initialize Dray problem.\n");
        return 1;
    }

    // Define central distribution depot
    dray_depot_t depot = {
        .id = 0,
        .coord = { .x = 0.0, .y = 0.0 },
        .window = { .ready = 0.0, .due = 28800.0 } // 8-hour shift
    };
    dray_problem_add_depot(prob, &depot);

    // Define 5 delivery customer stops
    dray_customer_t customers[5] = {
        { 1, { 5000.0, 5000.0 }, 10, { 3600.0, 14400.0 }, 900.0 },
        { 2, { 8000.0, 2000.0 }, 15, { 7200.0, 18000.0 }, 900.0 },
        { 3, { 2000.0, 9000.0 }, 12, { 5400.0, 16200.0 }, 900.0 },
        { 4, { -4000.0, 6000.0 }, 8, { 1800.0, 12600.0 }, 900.0 },
        { 5, { -6000.0, -2000.0 }, 14, { 3600.0, 14400.0 }, 900.0 }
    };

    for (int i = 0; i < 5; i++) {
        dray_problem_add_customer(prob, &customers[i]);
    }

    // Deploy 2 delivery vans
    dray_vehicle_t v1 = { 1, 35, 0, 0.0, 28800.0, 75.0, 1.2 };
    dray_vehicle_t v2 = { 2, 35, 0, 0.0, 28800.0, 75.0, 1.2 };
    dray_problem_add_vehicle(prob, &v1);
    dray_problem_add_vehicle(prob, &v2);

    // Compute travel matrix
    dray_problem_compute_euclidean_matrix(prob);

    printf("Ingested %zu customers across %zu depots.\n",
           dray_problem_get_customer_count(prob),
           dray_problem_get_depot_count(prob));

    // Optimize
    dray_config_t cfg = dray_default_config();
    cfg.max_iterations = 80;
    dray_solution_t* sol = dray_solve(prob, &cfg);

    if (sol && dray_solution_is_feasible(sol)) {
        printf("Optimization converged: FEASIBLE\n");
        printf("Total Fleet Distance: %.2f km\n", dray_solution_get_distance(sol) / 1000.0);
        printf("Total Operational Cost: $%.2f\n", dray_solution_get_cost(sol));

        size_t routes = dray_solution_get_route_count(sol);
        for (size_t r = 0; r < routes; r++) {
            size_t c_cnt = dray_solution_get_route_customer_count(sol, r);
            if (c_cnt == 0) continue;
            printf("  Route #%zu: Depot(0)", r + 1);
            for (size_t c = 0; c < c_cnt; c++) {
                printf(" -> Cust(%llu)", (unsigned long long)dray_solution_get_route_customer(sol, r, c));
            }
            printf(" -> Depot(0) [Load: %lld]\n", (long long)dray_solution_get_route_load(sol, r));
        }
    } else {
        printf("Solution infeasible or optimization failed.\n");
    }

    dray_solution_free(sol);
    dray_problem_free(prob);
    return 0;
}
