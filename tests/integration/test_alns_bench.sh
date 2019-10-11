#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Running ALNS Convergence Stress Test ==="
roc test "$ROOT_DIR/src/roc/Alns.roc"
echo "ALNS Convergence Stress Test PASSED!"
exit 0
