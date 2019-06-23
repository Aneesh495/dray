"""Benchmark problem instance generator for Dray VRPTW suites."""

import math
from typing import Tuple
from .models import Problem, Customer, Depot, Vehicle, Coord, TimeWindow

def generate_instance(
    num_customers: int = 25,
    num_vehicles: int = 5,
    vehicle_capacity: int = 100,
    cluster_pattern: str = "clustered",
    seed: int = 42
) -> Problem:
    """Generate a synthetic VRPTW problem instance."""
    depot = Depot(
        id=0,
        coord=Coord(x=50000.0, y=50000.0),
        window=TimeWindow(ready=0.0, due=86400.0)
    )

    customers = []
    # Deterministic pseudo-random generation
    s = seed
    def lcg():
        nonlocal s
        s = (s * 1103515245 + 12345) % 2147483648
        return s / 2147483648.0

    cluster_centers = [
        (30000.0, 30000.0),
        (70000.0, 30000.0),
        (30000.0, 70000.0),
        (70000.0, 70000.0),
    ]

    for i in range(1, num_customers + 1):
        if cluster_pattern == "clustered":
            cx, cy = cluster_centers[(i - 1) % len(cluster_centers)]
            r = lcg() * 12000.0
            theta = lcg() * 2.0 * math.pi
            x = cx + r * math.cos(theta)
            y = cy + r * math.sin(theta)
        else:
            x = 10000.0 + lcg() * 80000.0
            y = 10000.0 + lcg() * 80000.0

        demand = 5 + int(lcg() * 20.0)
        ready_h = lcg() * 8.0 * 3600.0
        window_width = 2.0 * 3600.0 + lcg() * 4.0 * 3600.0

        customers.append(Customer(
            id=i,
            coord=Coord(x=x, y=y),
            demand=demand,
            window=TimeWindow(ready=ready_h, due=ready_h + window_width),
            service_duration=600.0
        ))

    fleet = [
        Vehicle(
            id=v,
            capacity=vehicle_capacity,
            depot_id=0,
            earliest_start=0.0,
            latest_end=86400.0,
            fixed_cost=100.0,
            distance_cost_per_unit=1.0
        )
        for v in range(1, num_vehicles + 1)
    ]

    return Problem(depots=[depot], customers=customers, fleet=fleet)
