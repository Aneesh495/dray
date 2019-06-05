#include "dray_internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

extern void dray_tui_render_map(const dray_problem_t* prob, const dray_solution_t* sol);
extern void dray_run_benchmarks(void);

static void print_usage(const char* prog) {
    printf("Dray: High-Performance Logistics Fleet Optimization & Routing Engine\n\n");
    printf("Usage:\n");
    printf("  %s demo                    Run interactive 20-customer dispatch simulation\n", prog);
    printf("  %s bench                   Run nanosecond micro-benchmarks\n", prog);
    printf("  %s serve [--port PORT]     Start REST API daemon (default: 8080)\n", prog);
    printf("  %s verify                  Run end-to-end algorithmic invariant tests\n", prog);
    printf("  %s help                    Show this help message\n\n", prog);
}

static void run_demo(void) {
    printf("[dray] Initializing 20-customer multi-depot logistics scenario...\n");
    dray_problem_t* prob = dray_problem_create();

    dray_depot_t d0 = { 0, { 50.0, 50.0 }, { 0.0, 86400.0 } };
    dray_problem_add_depot(prob, &d0);

    // 20 realistic delivery points clustered in 3 zones
    double coords[20][2] = {
        { 55.0, 55.0 }, { 58.0, 62.0 }, { 52.0, 68.0 }, { 45.0, 65.0 }, { 42.0, 58.0 },
        { 65.0, 48.0 }, { 72.0, 52.0 }, { 78.0, 45.0 }, { 70.0, 38.0 }, { 62.0, 42.0 },
        { 38.0, 45.0 }, { 32.0, 38.0 }, { 28.0, 48.0 }, { 35.0, 52.0 }, { 40.0, 38.0 },
        { 50.0, 32.0 }, { 55.0, 25.0 }, { 45.0, 22.0 }, { 60.0, 75.0 }, { 48.0, 80.0 }
    };

    for (size_t i = 1; i <= 20; i++) {
        dray_customer_t c = {
            i,
            { coords[i - 1][0] * 1000.0, coords[i - 1][1] * 1000.0 },
            10 + (int64_t)(i % 5) * 5,
            { 0.0, 86400.0 },
            600.0
        };
        dray_problem_add_customer(prob, &c);
    }

    for (size_t v = 1; v <= 5; v++) {
        dray_vehicle_t veh = { v, 100, 0, 0.0, 86400.0, 100.0, 1.0 };
        dray_problem_add_vehicle(prob, &veh);
    }

    dray_problem_compute_euclidean_matrix(prob);

    printf("[dray] Executing ALNS metaheuristic with 2-opt local search...\n");
    dray_config_t cfg = dray_default_config();
    cfg.max_iterations = 150;
    dray_solution_t* sol = dray_solve(prob, &cfg);

    dray_tui_render_map(prob, sol);

    dray_solution_free(sol);
    dray_problem_free(prob);
}

static int run_verify(void) {
    printf("[dray] Running C native verification pass...\n");
    dray_problem_t* prob = dray_problem_create();

    dray_depot_t d0 = { 0, { 0.0, 0.0 }, { 0.0, 1000.0 } };
    dray_problem_add_depot(prob, &d0);

    dray_customer_t c1 = { 1, { 10.0, 0.0 }, 5, { 0.0, 500.0 }, 10.0 };
    dray_customer_t c2 = { 2, { 20.0, 0.0 }, 8, { 0.0, 500.0 }, 10.0 };
    dray_problem_add_customer(prob, &c1);
    dray_problem_add_customer(prob, &c2);

    dray_vehicle_t v1 = { 1, 20, 0, 0.0, 1000.0, 50.0, 1.0 };
    dray_problem_add_vehicle(prob, &v1);

    dray_problem_compute_euclidean_matrix(prob);

    dray_solution_t* sol = dray_solve_quick(prob);
    if (!sol || !sol->is_feasible) {
        printf("Verification FAILED: solution not feasible!\n");
        return 1;
    }

    if (sol->total_distance < 39.9 || sol->total_distance > 40.1) {
        printf("Verification FAILED: distance mismatch (got %.2f, expected 40.0)!\n", sol->total_distance);
        return 1;
    }

    printf("Verification PASSED: All 4 native assertions satisfied.\n");
    dray_solution_free(sol);
    dray_problem_free(prob);
    return 0;
}

int main(int argc, char** argv) {
    if (argc < 2) {
        run_demo();
        return 0;
    }

    const char* cmd = argv[1];
    if (strcmp(cmd, "demo") == 0) {
        run_demo();
        return 0;
    } else if (strcmp(cmd, "bench") == 0) {
        dray_run_benchmarks();
        return 0;
    } else if (strcmp(cmd, "verify") == 0) {
        return run_verify();
    } else if (strcmp(cmd, "serve") == 0) {
        int port = 8080;
        if (argc >= 4 && strcmp(argv[2], "--port") == 0) {
            port = atoi(argv[3]);
        }
        if (!dray_server_start(port)) {
            fprintf(stderr, "Failed to start server on port %d\n", port);
            return 1;
        }
        printf("Press Ctrl+C to stop server.\n");
        // Run loop for server
        while (1) {
            pause();
        }
    } else if (strcmp(cmd, "help") == 0 || strcmp(cmd, "-h") == 0 || strcmp(cmd, "--help") == 0) {
        print_usage(argv[0]);
        return 0;
    } else {
        print_usage(argv[0]);
        return 1;
    }
}
