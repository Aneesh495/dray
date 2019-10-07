#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Running K-D Tree Spatial Accuracy Test ==="
roc test "$ROOT_DIR/src/roc/KdTree.roc"
echo "K-D Tree Spatial Accuracy Test PASSED!"
exit 0
