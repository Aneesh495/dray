#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Running Contraction Hierarchies Invariant Test ==="
roc test "$ROOT_DIR/src/roc/Contraction.roc"
echo "Contraction Hierarchies Invariant Test PASSED!"
exit 0
