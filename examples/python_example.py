#!/usr/bin/env python3
"""Dray Python SDK Example: Solving clustered delivery instances."""

import os
import sys

# Ensure pydray is in path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../src/python")))

from pydray.client import DrayClient
from pydray.generator import generate_instance
from pydray.visualizer import print_ascii_summary, export_geojson

def main():
    print("=== DRAY PYTHON SDK LOGISTICS DEMO ===")

    lib_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../lib/libdray.dylib"))
    client = DrayClient(lib_path=lib_path)

    # Generate 15-customer clustered problem
    problem = generate_instance(num_customers=15, num_vehicles=3, vehicle_capacity=80, seed=42)
    print(f"Loaded {len(problem.customers)} customers across {len(problem.fleet)} vehicles.")

    # Solve using ALNS
    solution = client.solve(problem, iterations=120)

    print(f"Feasibility: {'PASS' if solution.is_feasible else 'FAIL'}")
    print(f"Total Distance: {solution.total_distance / 1000.0:.2f} km")
    if solution.metrics:
        print(f"Capacity Utilization: {solution.metrics.capacity_utilization * 100.0:.1f}%")
        print(f"Carbon Footprint: {solution.metrics.total_carbon_kg:.2f} kg CO2")

    print_ascii_summary(solution)

if __name__ == "__main__":
    main()
