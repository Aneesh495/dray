#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "$ROOT_DIR/bin/dray" ]; then
    make -C "$ROOT_DIR/src/c" all
fi

"$ROOT_DIR/bin/dray" demo
