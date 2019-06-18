"""Client bindings for libdray native library and REST daemon."""

import ctypes
import os
import sys
from typing import Optional, List
from .models import Problem, Solution, Route, Metrics, Customer, Depot, Vehicle, Coord, TimeWindow

class CDrayCoord(ctypes.Structure):
    _fields_ = [("x", ctypes.c_double), ("y", ctypes.c_double)]

class CDrayTimeWindow(ctypes.Structure):
    _fields_ = [("ready", ctypes.c_double), ("due", ctypes.c_double)]

class CDrayCustomer(ctypes.Structure):
    _fields_ = [
        ("id", ctypes.c_uint64),
        ("coord", CDrayCoord),
        ("demand", ctypes.c_int64),
        ("window", CDrayTimeWindow),
        ("service_duration", ctypes.c_double),
    ]

class CDrayDepot(ctypes.Structure):
    _fields_ = [
        ("id", ctypes.c_uint64),
        ("coord", CDrayCoord),
        ("window", CDrayTimeWindow),
    ]

class CDrayVehicle(ctypes.Structure):
    _fields_ = [
        ("id", ctypes.c_uint64),
        ("capacity", ctypes.c_int64),
        ("depot_id", ctypes.c_uint64),
        ("earliest_start", ctypes.c_double),
        ("latest_end", ctypes.c_double),
        ("fixed_cost", ctypes.c_double),
        ("distance_cost_per_unit", ctypes.c_double),
    ]

class CDrayMetrics(ctypes.Structure):
    _fields_ = [
        ("total_distance_km", ctypes.c_double),
        ("total_duration_hours", ctypes.c_double),
        ("active_vehicle_count", ctypes.c_uint64),
        ("capacity_utilization", ctypes.c_double),
        ("total_carbon_kg", ctypes.c_double),
        ("average_wait_time_sec", ctypes.c_double),
        ("unassigned_count", ctypes.c_uint64),
    ]

class CDrayConfig(ctypes.Structure):
    _fields_ = [
        ("max_iterations", ctypes.c_uint64),
        ("start_temperature", ctypes.c_double),
        ("cooling_rate", ctypes.c_double),
        ("segment_size", ctypes.c_uint64),
        ("decay_rate", ctypes.c_double),
        ("min_destroy", ctypes.c_uint64),
        ("max_destroy", ctypes.c_uint64),
        ("seed", ctypes.c_uint64),
    ]

class DrayClient:
    """High-level client interface for the Dray optimization engine."""

    def __init__(self, lib_path: Optional[str] = None):
        self._lib = None
        if lib_path is None:
            # Try finding libdray in standard build locations
            base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../lib"))
            ext = ".dylib" if sys.platform == "darwin" else ".so"
            candidate = os.path.join(base_dir, f"libdray{ext}")
            if os.path.exists(candidate):
                lib_path = candidate

        if lib_path and os.path.exists(lib_path):
            try:
                self._lib = ctypes.CDLL(lib_path)
                self._setup_ffi()
            except Exception as e:
                self._lib = None

    def _setup_ffi(self):
        lib = self._lib
        lib.dray_default_config.restype = CDrayConfig
        lib.dray_default_config.argtypes = []

        lib.dray_problem_create.restype = ctypes.c_void_p
        lib.dray_problem_create.argtypes = []

        lib.dray_problem_free.restype = None
        lib.dray_problem_free.argtypes = [ctypes.c_void_p]

        lib.dray_problem_add_depot.restype = ctypes.c_bool
        lib.dray_problem_add_depot.argtypes = [ctypes.c_void_p, ctypes.POINTER(CDrayDepot)]

        lib.dray_problem_add_customer.restype = ctypes.c_bool
        lib.dray_problem_add_customer.argtypes = [ctypes.c_void_p, ctypes.POINTER(CDrayCustomer)]

        lib.dray_problem_add_vehicle.restype = ctypes.c_bool
        lib.dray_problem_add_vehicle.argtypes = [ctypes.c_void_p, ctypes.POINTER(CDrayVehicle)]

        lib.dray_problem_compute_euclidean_matrix.restype = ctypes.c_bool
        lib.dray_problem_compute_euclidean_matrix.argtypes = [ctypes.c_void_p]

        lib.dray_solve.restype = ctypes.c_void_p
        lib.dray_solve.argtypes = [ctypes.c_void_p, ctypes.POINTER(CDrayConfig)]

        lib.dray_solve_quick.restype = ctypes.c_void_p
        lib.dray_solve_quick.argtypes = [ctypes.c_void_p]

        lib.dray_solution_free.restype = None
        lib.dray_solution_free.argtypes = [ctypes.c_void_p]

        lib.dray_solution_is_feasible.restype = ctypes.c_bool
        lib.dray_solution_is_feasible.argtypes = [ctypes.c_void_p]

        lib.dray_solution_get_distance.restype = ctypes.c_double
        lib.dray_solution_get_distance.argtypes = [ctypes.c_void_p]

        lib.dray_solution_get_cost.restype = ctypes.c_double
        lib.dray_solution_get_cost.argtypes = [ctypes.c_void_p]

        lib.dray_solution_get_route_count.restype = ctypes.c_size_t
        lib.dray_solution_get_route_count.argtypes = [ctypes.c_void_p]

        lib.dray_solution_get_route_customer_count.restype = ctypes.c_size_t
        lib.dray_solution_get_route_customer_count.argtypes = [ctypes.c_void_p, ctypes.c_size_t]

        lib.dray_solution_get_route_customer.restype = ctypes.c_uint64
        lib.dray_solution_get_route_customer.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_size_t]

        lib.dray_solution_get_route_distance.restype = ctypes.c_double
        lib.dray_solution_get_route_distance.argtypes = [ctypes.c_void_p, ctypes.c_size_t]

        lib.dray_solution_get_route_duration.restype = ctypes.c_double
        lib.dray_solution_get_route_duration.argtypes = [ctypes.c_void_p, ctypes.c_size_t]

        lib.dray_solution_get_route_load.restype = ctypes.c_int64
        lib.dray_solution_get_route_load.argtypes = [ctypes.c_void_p, ctypes.c_size_t]

        lib.dray_solution_get_metrics.restype = CDrayMetrics
        lib.dray_solution_get_metrics.argtypes = [ctypes.c_void_p, ctypes.c_void_p]

    def solve(self, problem: Problem, iterations: int = 100) -> Solution:
        """Solve a VRPTW problem instance using the native Dray engine."""
        if self._lib is None:
            raise RuntimeError("libdray native library not loaded. Build the project first via make.")

        p_handle = self._lib.dray_problem_create()
        try:
            for d in problem.depots:
                cd = CDrayDepot(
                    id=d.id,
                    coord=CDrayCoord(x=d.coord.x, y=d.coord.y),
                    window=CDrayTimeWindow(ready=d.window.ready, due=d.window.due)
                )
                self._lib.dray_problem_add_depot(p_handle, ctypes.byref(cd))

            for c in problem.customers:
                cc = CDrayCustomer(
                    id=c.id,
                    coord=CDrayCoord(x=c.coord.x, y=c.coord.y),
                    demand=c.demand,
                    window=CDrayTimeWindow(ready=c.window.ready, due=c.window.due),
                    service_duration=c.service_duration
                )
                self._lib.dray_problem_add_customer(p_handle, ctypes.byref(cc))

            for v in problem.fleet:
                cv = CDrayVehicle(
                    id=v.id,
                    capacity=v.capacity,
                    depot_id=v.depot_id,
                    earliest_start=v.earliest_start,
                    latest_end=v.latest_end,
                    fixed_cost=v.fixed_cost,
                    distance_cost_per_unit=v.distance_cost_per_unit
                )
                self._lib.dray_problem_add_vehicle(p_handle, ctypes.byref(cv))

            self._lib.dray_problem_compute_euclidean_matrix(p_handle)

            cfg = self._lib.dray_default_config()
            cfg.max_iterations = iterations

            s_handle = self._lib.dray_solve(p_handle, ctypes.byref(cfg))
            try:
                is_feasible = bool(self._lib.dray_solution_is_feasible(s_handle))
                tot_dist = float(self._lib.dray_solution_get_distance(s_handle))
                tot_cost = float(self._lib.dray_solution_get_cost(s_handle))
                num_routes = int(self._lib.dray_solution_get_route_count(s_handle))

                routes: List[Route] = []
                for r_idx in range(num_routes):
                    cust_cnt = int(self._lib.dray_solution_get_route_customer_count(s_handle, r_idx))
                    c_list = [
                        int(self._lib.dray_solution_get_route_customer(s_handle, r_idx, c_idx))
                        for c_idx in range(cust_cnt)
                    ]
                    r_dist = float(self._lib.dray_solution_get_route_distance(s_handle, r_idx))
                    r_dur = float(self._lib.dray_solution_get_route_duration(s_handle, r_idx))
                    r_load = int(self._lib.dray_solution_get_route_load(s_handle, r_idx))

                    v_id = problem.fleet[r_idx].id if r_idx < len(problem.fleet) else r_idx
                    depot_id = problem.fleet[r_idx].depot_id if r_idx < len(problem.fleet) else 0

                    routes.append(Route(
                        vehicle_id=v_id,
                        depot_id=depot_id,
                        customers=c_list,
                        distance=r_dist,
                        duration=r_dur,
                        load=r_load,
                        capacity_excess=0,
                        time_lateness=0.0,
                        is_feasible=True
                    ))

                c_metrics = self._lib.dray_solution_get_metrics(p_handle, s_handle)
                py_metrics = Metrics(
                    total_distance_km=float(c_metrics.total_distance_km),
                    total_duration_hours=float(c_metrics.total_duration_hours),
                    active_vehicle_count=int(c_metrics.active_vehicle_count),
                    capacity_utilization=float(c_metrics.capacity_utilization),
                    total_carbon_kg=float(c_metrics.total_carbon_kg),
                    average_wait_time_sec=float(c_metrics.average_wait_time_sec),
                    unassigned_count=int(c_metrics.unassigned_count)
                )

                return Solution(
                    routes=routes,
                    unassigned=[],
                    total_distance=tot_dist,
                    total_cost=tot_cost,
                    is_feasible=is_feasible,
                    metrics=py_metrics
                )
            finally:
                self._lib.dray_solution_free(s_handle)
        finally:
            self._lib.dray_problem_free(p_handle)
