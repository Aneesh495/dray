#include "dray_internal.h"
#include <stdio.h>

#define ANSI_RESET   "\033[0m"
#define ANSI_BOLD    "\033[1m"
#define ANSI_RED     "\033[31m"
#define ANSI_GREEN   "\033[32m"
#define ANSI_YELLOW  "\033[33m"
#define ANSI_BLUE    "\033[34m"
#define ANSI_MAGENTA "\033[35m"
#define ANSI_CYAN    "\033[36m"
#define ANSI_GRAY    "\033[90m"

static const char* ROUTE_COLORS[] = {
    ANSI_GREEN,
    ANSI_CYAN,
    ANSI_MAGENTA,
    ANSI_YELLOW,
    ANSI_BLUE,
    ANSI_RED,
};
#define NUM_ROUTE_COLORS 6

void dray_tui_render_map(const dray_problem_t* prob, const dray_solution_t* sol) {
    if (!prob || !sol) return;

    printf("\n" ANSI_BOLD "=== DRAY FLEET LOGISTICS DISPATCH MAP ===" ANSI_RESET "\n\n");

    // Grid bounds
    double min_x = DRAY_INFINITY, max_x = -DRAY_INFINITY;
    double min_y = DRAY_INFINITY, max_y = -DRAY_INFINITY;

    for (size_t i = 0; i < prob->depot_count; i++) {
        if (prob->depots[i].coord.x < min_x) min_x = prob->depots[i].coord.x;
        if (prob->depots[i].coord.x > max_x) max_x = prob->depots[i].coord.x;
        if (prob->depots[i].coord.y < min_y) min_y = prob->depots[i].coord.y;
        if (prob->depots[i].coord.y > max_y) max_y = prob->depots[i].coord.y;
    }

    for (size_t i = 0; i < prob->customer_count; i++) {
        if (prob->customers[i].coord.x < min_x) min_x = prob->customers[i].coord.x;
        if (prob->customers[i].coord.x > max_x) max_x = prob->customers[i].coord.x;
        if (prob->customers[i].coord.y < min_y) min_y = prob->customers[i].coord.y;
        if (prob->customers[i].coord.y > max_y) max_y = prob->customers[i].coord.y;
    }

    double width = max_x - min_x;
    double height = max_y - min_y;
    if (width < 1.0) width = 10.0;
    if (height < 1.0) height = 10.0;

    int grid_w = 60;
    int grid_h = 20;

    char grid[20][60];
    const char* color_grid[20][60];

    for (int y = 0; y < grid_h; y++) {
        for (int x = 0; x < grid_w; x++) {
            grid[y][x] = '.';
            color_grid[y][x] = ANSI_GRAY;
        }
    }

    // Place depots
    for (size_t i = 0; i < prob->depot_count; i++) {
        int gx = (int)((prob->depots[i].coord.x - min_x) / width * (grid_w - 2));
        int gy = (int)((prob->depots[i].coord.y - min_y) / height * (grid_h - 2));
        gy = grid_h - 1 - gy;
        if (gx >= 0 && gx < grid_w && gy >= 0 && gy < grid_h) {
            grid[gy][gx] = 'D';
            color_grid[gy][gx] = ANSI_BOLD ANSI_RED;
        }
    }

    // Place customers with route colors
    for (size_t r = 0; r < sol->route_count; r++) {
        const char* col = ROUTE_COLORS[r % NUM_ROUTE_COLORS];
        for (size_t c = 0; c < sol->routes[r].customer_count; c++) {
            uint64_t cid = sol->routes[r].customers[c];
            const dray_customer_t* cust = dray_find_customer(prob, cid);
            if (cust) {
                int gx = (int)((cust->coord.x - min_x) / width * (grid_w - 2));
                int gy = (int)((cust->coord.y - min_y) / height * (grid_h - 2));
                gy = grid_h - 1 - gy;
                if (gx >= 0 && gx < grid_w && gy >= 0 && gy < grid_h) {
                    grid[gy][gx] = (char)('1' + (c % 9));
                    color_grid[gy][gx] = col;
                }
            }
        }
    }

    // Print border and grid
    printf("  +");
    for (int x = 0; x < grid_w; x++) printf("-");
    printf("+\n");

    for (int y = 0; y < grid_h; y++) {
        printf("  |");
        for (int x = 0; x < grid_w; x++) {
            printf("%s%c" ANSI_RESET, color_grid[y][x], grid[y][x]);
        }
        printf("|\n");
    }

    printf("  +");
    for (int x = 0; x < grid_w; x++) printf("-");
    printf("+\n\n");

    // Print Route Itineraries
    printf(ANSI_BOLD "=== DISPATCHED ITINERARIES ===" ANSI_RESET "\n");
    for (size_t r = 0; r < sol->route_count; r++) {
        if (sol->routes[r].customer_count == 0) continue;
        const char* col = ROUTE_COLORS[r % NUM_ROUTE_COLORS];
        printf("%sVehicle #%zu [Depot %llu]:" ANSI_RESET " (Dist: %.2f km, Duration: %.2f h, Load: %lld)\n",
               col, r + 1, (unsigned long long)sol->routes[r].depot_id,
               sol->routes[r].distance / 1000.0,
               sol->routes[r].duration / 3600.0,
               (long long)sol->routes[r].load);

        printf("  Path: Depot(%llu)", (unsigned long long)sol->routes[r].depot_id);
        for (size_t c = 0; c < sol->routes[r].customer_count; c++) {
            printf(" -> Cust(%llu)", (unsigned long long)sol->routes[r].customers[c]);
        }
        printf(" -> Depot(%llu)\n\n", (unsigned long long)sol->routes[r].depot_id);
    }

    // Print Summary Metrics
    dray_metrics_t m = dray_solution_get_metrics(prob, sol);
    printf(ANSI_BOLD "=== FLEET PERFORMANCE METRICS ===" ANSI_RESET "\n");
    printf("  Total Distance:         " ANSI_CYAN "%.2f km" ANSI_RESET "\n", m.total_distance_km);
    printf("  Total Operating Time:   " ANSI_CYAN "%.2f hours" ANSI_RESET "\n", m.total_duration_hours);
    printf("  Active Fleet Size:      " ANSI_CYAN "%llu vehicles" ANSI_RESET "\n", (unsigned long long)m.active_vehicle_count);
    printf("  Capacity Utilization:   " ANSI_CYAN "%.1f%%" ANSI_RESET "\n", m.capacity_utilization * 100.0);
    printf("  Estimated CO2:          " ANSI_CYAN "%.2f kg" ANSI_RESET "\n", m.total_carbon_kg);
    printf("  Schedule Feasibility:   %s\n", sol->is_feasible ? ANSI_GREEN "FEASIBLE" ANSI_RESET : ANSI_RED "INFEASIBLE" ANSI_RESET);
    printf("\n");
}
