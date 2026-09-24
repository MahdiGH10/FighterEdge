#!/usr/bin/env sh
# Refuses to publish legal pages that still contain owner placeholders.
# Runs as the Firebase Hosting predeploy hook and in CI's release workflow.
set -eu
dir="${1:-$(dirname "$0")/public}"
if grep -rn "TODO(owner)" "$dir"; then
  echo "Legal pages still contain TODO(owner) placeholders (listed above)." >&2
  echo "Fill them in before publishing: see fighter_edge/hosting/README.md." >&2
  exit 1
fi
echo "Legal pages: no placeholders left."
