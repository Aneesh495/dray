#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Running Dray REST API Daemon Integration Test ==="

PORT=18989
"$ROOT_DIR/bin/dray" serve --port "$PORT" &
SERVER_PID=$!

# Ensure cleanup on exit
trap "kill -9 $SERVER_PID 2>/dev/null || true" EXIT

# Wait for server to bind
sleep 1

echo "Testing GET /api/v1/health..."
HEALTH_RESP=$(curl -s "http://127.0.0.1:$PORT/api/v1/health")
echo "Health Response: $HEALTH_RESP"
if ! echo "$HEALTH_RESP" | grep -q "healthy"; then
    echo "Health check failed!"
    exit 1
fi

echo "Testing GET /api/v1/metrics..."
METRICS_RESP=$(curl -s "http://127.0.0.1:$PORT/api/v1/metrics")
echo "Metrics Response: $METRICS_RESP"
if ! echo "$METRICS_RESP" | grep -q "operational"; then
    echo "Metrics check failed!"
    exit 1
fi

echo "REST API Daemon Test PASSED!"
exit 0
