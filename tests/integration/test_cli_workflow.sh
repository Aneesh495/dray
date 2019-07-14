#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="$ROOT_DIR/bin/dray"

echo "=== Running Dray CLI Workflow Integration Test ==="

if [ ! -f "$BIN" ]; then
    echo "Building dray binary first..."
    make -C "$ROOT_DIR/src/c" all
fi

echo "1. Testing verify subcommand..."
"$BIN" verify

echo "2. Testing demo subcommand..."
"$BIN" demo > /dev/null

echo "3. Testing bench subcommand..."
"$BIN" bench > /dev/null

echo "4. Testing help subcommand..."
"$BIN" help > /dev/null

echo "CLI Workflow Test PASSED!"
exit 0
