#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Running Multi-Depot Fleet Allocation Test ==="
PYTHONPATH="$ROOT_DIR/src/python" python3 -c "
import json
import os
from pydray.models import Coord, TimeWindow, Customer, Depot, Vehicle, Problem
from pydray.client import DrayClient

instance_path = os.path.join('$ROOT_DIR', 'tests', 'instances', 'multi_depot_40.json')
with open(instance_path, 'r') as f:
    data = json.load(f)

depots = [
    Depot(id=d['id'], coord=Coord(d['x'], d['y']), window=TimeWindow(d['ready'], d['due']))
    for d in data['depots']
]
customers = [
    Customer(id=c['id'], coord=Coord(c['x'], c['y']), demand=c['demand'],
             window=TimeWindow(c['ready'], c['due']), service_duration=c['service'])
    for c in data['customers']
]
fleet = [
    Vehicle(id=v['id'], capacity=v['capacity'], depot_id=v['depot_id'],
            earliest_start=v['earliest_start'], latest_end=v['latest_end'])
    for v in data['fleet']
]

prob = Problem(depots=depots, customers=customers, fleet=fleet)
lib_path = os.path.join('$ROOT_DIR', 'lib', 'libdray.dylib')
client = DrayClient(lib_path=lib_path)
sol = client.solve(prob, iterations=50)

print(f'Multi-depot solve completed: {len(sol.routes)} routes, feasible: {sol.is_feasible}')
assert sol.total_distance > 0.0, 'Distance must be non-zero'
print('Multi-Depot Test PASSED!')
"
exit 0
