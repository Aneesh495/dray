#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Running Dray Complete Integration Test Suite ==="

"$ROOT_DIR/tests/integration/test_cli_workflow.sh"
"$ROOT_DIR/tests/integration/test_capacity_constraints.sh"
"$ROOT_DIR/tests/integration/test_time_window_constraints.sh"
"$ROOT_DIR/tests/integration/test_ch_invariants.sh"
"$ROOT_DIR/tests/integration/test_multi_depot.sh"
"$ROOT_DIR/tests/integration/test_rest_daemon.sh"
"$ROOT_DIR/tests/integration/test_dynamic_insertion.sh"
"$ROOT_DIR/tests/integration/test_kd_tree_spatial.sh"
"$ROOT_DIR/tests/integration/test_alns_bench.sh"
"$ROOT_DIR/tests/integration/test_localsearch_untangle.sh"
"$ROOT_DIR/tests/integration/test_clarke_wright.sh"
"$ROOT_DIR/tests/integration/test_carbon_metrics.sh"

echo ""
echo "All 12 Integration Test Suites PASSED!"
exit 0
