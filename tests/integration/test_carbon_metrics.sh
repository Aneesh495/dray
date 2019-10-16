#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Running Carbon Footprint and Fleet Metrics Test ==="
roc test "$ROOT_DIR/src/roc/Metrics.roc"
echo "Carbon Footprint and Fleet Metrics Test PASSED!"
exit 0
