#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Running Time Window Constraint Test ==="
PYTHONPATH="$ROOT_DIR/src/python" python3 -c "
from pydray.models import Coord, TimeWindow, Customer, Depot, Vehicle, Problem
from pydray.client import DrayClient
import os

lib_path = os.path.join('$ROOT_DIR', 'lib', 'libdray.dylib')
client = DrayClient(lib_path=lib_path)

d0 = Depot(id=0, coord=Coord(0.0, 0.0), window=TimeWindow(0.0, 1000.0))
# Customer is 1000 km away (travel time > 60000s), but window due is only 100s
c1 = Customer(id=1, coord=Coord(1000000.0, 0.0), demand=5, window=TimeWindow(0.0, 100.0), service_duration=10.0)
v1 = Vehicle(id=1, capacity=20, depot_id=0, earliest_start=0.0, latest_end=1000.0)

prob = Problem(depots=[d0], customers=[c1], fleet=[v1])
sol = client.solve(prob, iterations=5)

assert sol.routes[0].customers == [], 'Customer with impossible time window must not be scheduled'
print('Time Window Constraint Test PASSED!')
"
exit 0
