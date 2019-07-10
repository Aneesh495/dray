"""Tests for Dray Python SDK client and models."""

import os
import unittest
from pydray.models import Coord, TimeWindow, Customer, Depot, Vehicle, Problem
from pydray.client import DrayClient
from pydray.generator import generate_instance
from pydray.visualizer import export_geojson

class TestDrayClient(unittest.TestCase):
    def setUp(self):
        lib_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../lib"))
        lib_path = os.path.join(lib_dir, "libdray.dylib")
        self.client = DrayClient(lib_path=lib_path)

    def test_solve_simple_instance(self):
        d0 = Depot(id=0, coord=Coord(0.0, 0.0), window=TimeWindow(0.0, 1000.0))
        c1 = Customer(id=1, coord=Coord(1000.0, 0.0), demand=5, window=TimeWindow(0.0, 500.0), service_duration=10.0)
        c2 = Customer(id=2, coord=Coord(2000.0, 0.0), demand=8, window=TimeWindow(0.0, 500.0), service_duration=10.0)
        v1 = Vehicle(id=1, capacity=20, depot_id=0, earliest_start=0.0, latest_end=1000.0, fixed_cost=50.0)

        prob = Problem(depots=[d0], customers=[c1, c2], fleet=[v1])
        sol = self.client.solve(prob, iterations=10)

        self.assertTrue(sol.is_feasible)
        self.assertAlmostEqual(sol.total_distance, 4000.0, delta=10.0)
        self.assertEqual(len(sol.routes), 1)
        self.assertEqual(sol.routes[0].customers, [1, 2])

    def test_generator_and_geojson_export(self):
        prob = generate_instance(num_customers=10, num_vehicles=3, vehicle_capacity=50, seed=123)
        self.assertEqual(len(prob.customers), 10)
        self.assertEqual(len(prob.fleet), 3)

        sol = self.client.solve(prob, iterations=20)
        geo = export_geojson(prob, sol)
        self.assertEqual(geo["type"], "FeatureCollection")
        self.assertTrue(len(geo["features"]) > 10)

if __name__ == "__main__":
    unittest.main()
