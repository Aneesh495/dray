# API Reference

## 1. C ABI Reference (`dray.h`)

### Problem Construction
- `dray_problem_t* dray_problem_create(void)`: Allocate a new empty problem container.
- `void dray_problem_free(dray_problem_t* prob)`: Free a problem container and associated matrices.
- `bool dray_problem_add_depot(dray_problem_t* prob, const dray_depot_t* depot)`: Append depot stop.
- `bool dray_problem_add_customer(dray_problem_t* prob, const dray_customer_t* customer)`: Append customer stop.
- `bool dray_problem_add_vehicle(dray_problem_t* prob, const dray_vehicle_t* vehicle)`: Append vehicle profile.
- `bool dray_problem_set_matrix(dray_problem_t* prob, size_t dim, const double* dists, const double* times)`: Set custom distance matrix.
- `bool dray_problem_compute_euclidean_matrix(dray_problem_t* prob)`: Compute distance matrix from coordinates.

### Optimization Solvers
- `dray_solution_t* dray_solve(const dray_problem_t* prob, const dray_config_t* config)`: Execute full ALNS optimization.
- `dray_solution_t* dray_solve_quick(const dray_problem_t* prob)`: Quick solve with default settings.
- `void dray_solution_free(dray_solution_t* sol)`: Free solution container.

### Solution Accessors
- `bool dray_solution_is_feasible(const dray_solution_t* sol)`: Check feasibility.
- `double dray_solution_get_distance(const dray_solution_t* sol)`: Get total distance in meters.
- `double dray_solution_get_cost(const dray_solution_t* sol)`: Get objective cost value.
- `size_t dray_solution_get_route_count(const dray_solution_t* sol)`: Number of vehicle routes.
- `size_t dray_solution_get_route_customer_count(const dray_solution_t* sol, size_t route_idx)`: Number of customers on route.
- `uint64_t dray_solution_get_route_customer(const dray_solution_t* sol, size_t route_idx, size_t cust_idx)`: Customer ID at position.
- `dray_metrics_t dray_solution_get_metrics(const dray_problem_t* prob, const dray_solution_t* sol)`: Compute fleet KPIs.

---

## 2. Python SDK Reference (`pydray`)

### Classes
- `DrayClient(lib_path: Optional[str] = None)`: Client connecting to native `libdray`.
- `Problem(depots, customers, fleet)`: Problem definition container.
- `Solution(routes, unassigned, total_distance, total_cost, is_feasible, metrics)`: Optimization result.
- `generate_instance(num_customers, num_vehicles, vehicle_capacity, seed)`: Synthetic benchmark generator.
- `export_geojson(problem, solution)`: Export routes as GeoJSON FeatureCollection.
