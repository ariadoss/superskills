#!/usr/bin/env bash
# Write the public-repo variant of session.md into <dir>/session.md.
# Usage: make_public_variant.sh <dir>
# Same text, with the Visibility line swapped from PRIVATE to PUBLIC.
set -euo pipefail
dir="${1:-}"
if [ -z "$dir" ] || [ "$dir" = "/" ]; then
  echo "usage: make_public_variant.sh <dir>  (dir must be non-empty and not /)" >&2
  exit 2
fi
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/session.md"
mkdir -p "$dir"
sed 's/^Repo: acme-invoices\. Visibility: PRIVATE\./Repo: acme-invoices. Visibility: PUBLIC./' "$src" > "$dir/session.md"
