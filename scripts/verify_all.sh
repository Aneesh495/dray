#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=========================================================="
echo "          DRAY SYSTEM-WIDE VERIFICATION PASS              "
echo "=========================================================="

echo "[1/5] Checking code formatting and forbidden dashes..."
"$ROOT_DIR/scripts/lint_dashes.sh"

echo "[2/5] Running pure Roc test suites..."
roc test "$ROOT_DIR/src/roc/Tests.roc"

echo "[3/5] Compiling native C library and CLI..."
make -C "$ROOT_DIR/src/c" clean all

echo "[4/5] Running C native verification pass and micro-benchmarks..."
"$ROOT_DIR/bin/dray" verify
"$ROOT_DIR/bin/dray" bench

echo "[5/5] Running Python SDK unittest suite and integration scripts..."
PYTHONPATH="$ROOT_DIR/src/python" python3 -m unittest discover -s "$ROOT_DIR/src/python/tests"
"$ROOT_DIR/tests/integration/test_cli_workflow.sh"
"$ROOT_DIR/tests/integration/test_capacity_constraints.sh"
"$ROOT_DIR/tests/integration/test_time_window_constraints.sh"
"$ROOT_DIR/tests/integration/test_ch_invariants.sh"

echo ""
echo "=========================================================="
echo "      ALL VERIFICATION CHECKS PASSED (ZERO BUGS)          "
echo "=========================================================="
exit 0
