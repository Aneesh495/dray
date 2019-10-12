#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Running 2-Opt Loop Untangling Test ==="
roc test "$ROOT_DIR/src/roc/LocalSearch.roc"
echo "2-Opt Loop Untangling Test PASSED!"
exit 0
