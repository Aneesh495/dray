#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Running Clarke-Wright Savings Integration Test ==="
roc test "$ROOT_DIR/src/roc/Construction.roc"
echo "Clarke-Wright Savings Integration Test PASSED!"
exit 0
