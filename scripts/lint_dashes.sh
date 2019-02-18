#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

echo "Scanning repository for prohibited dashes..."

while IFS= read -r file; do
    if grep -n -P '[\x{2014}\x{2013}]' "$file" 2>/dev/null; then
        echo "Found prohibited dash in $file"
        FAIL=1
    fi
done < <(find "$ROOT_DIR" -type f \
    ! -path '*/.git/*' \
    ! -path '*/bin/*' \
    ! -path '*/lib/*' \
    ! -path '*/__pycache__/*' \
    ! -path '*.pyc' \
    ! -path '*.tar.gz' \
    ! -path '*.o' \
    ! -path '*.so' \
    ! -path '*.dylib')

if [ "$FAIL" -eq 1 ]; then
    echo "Check failed: em dash or en dash detected."
    exit 1
fi

echo "Check passed: no forbidden dashes found."
exit 0
