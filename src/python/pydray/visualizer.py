"""Visualizer and GeoJSON route exporter for Dray solutions."""

import json
from typing import Dict, Any
from .models import Problem, Solution

def export_geojson(problem: Problem, solution: Solution) -> Dict[str, Any]:
    """Export solution routes as GeoJSON FeatureCollection."""
    features = []

    # Map depots
    for d in problem.depots:
        features.append({
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [d.coord.x / 1000.0, d.coord.y / 1000.0]
            },
            "properties": {
                "type": "depot",
                "id": d.id
            }
        })

    # Map customers
    for c in problem.customers:
        features.append({
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [c.coord.x / 1000.0, c.coord.y / 1000.0]
            },
            "properties": {
                "type": "customer",
                "id": c.id,
                "demand": c.demand
            }
        })

    # Map route LineStrings
    coord_lookup = {d.id: d.coord for d in problem.depots}
    for c in problem.customers:
        coord_lookup[c.id] = c.coord

    for r in solution.routes:
        if not r.customers:
            continue
        line_coords = [coord_lookup[r.depot_id]]
        for cid in r.customers:
            line_coords.append(coord_lookup[cid])
        line_coords.append(coord_lookup[r.depot_id])

        features.append({
            "type": "Feature",
            "geometry": {
                "type": "LineString",
                "coordinates": [[pt.x / 1000.0, pt.y / 1000.0] for pt in line_coords]
            },
            "properties": {
                "type": "route",
                "vehicle_id": r.vehicle_id,
                "distance_km": r.distance / 1000.0,
                "load": r.load
            }
        })

    return {
        "type": "FeatureCollection",
        "features": features
    }

def print_ascii_summary(solution: Solution):
    """Print clean summary table of solution routes."""
    print("Route Summary:")
    print("=" * 60)
    for r in solution.routes:
        if not r.customers:
            continue
        cust_str = " -> ".join(str(c) for c in r.customers)
        print(f"Vehicle #{r.vehicle_id}: Depot -> {cust_str} -> Depot")
        print(f"  Dist: {r.distance/1000.0:.2f} km | Duration: {r.duration/3600.0:.2f} h | Load: {r.load}")
    print("=" * 60)
