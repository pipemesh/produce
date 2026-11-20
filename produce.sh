#!/usr/bin/env bash
# One entry of the dispatching job's output manifest, as a line of a
# pipemesh-produces-<key> artifact that Pipemesh imports when the run
# succeeds (DESIGN-V59 §7). Verified here, where the credentials are.
set -euo pipefail

if ! [[ "$PM_KEY" =~ ^[A-Za-z0-9_-]+$ ]]; then echo "::error::key '$PM_KEY' must be letters, digits, _ and -"; exit 1; fi
if [ "$PM_TYPE" != oci ]; then
  echo "::error::type must be oci (a file is an uploaded artifact named after its key)"; exit 1
fi
if [ -z "$PM_REF" ]; then echo "::error::ref is required: where the image lives (registry/repo)"; exit 1; fi
[[ "$PM_DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "::error::an oci digest is sha256:<64 hex>"; exit 1; }

if [ "$PM_VERIFY" = true ]; then
  if command -v docker >/dev/null 2>&1; then
    docker buildx imagetools inspect "${PM_REF%%@*}@$PM_DIGEST" >/dev/null || { echo "::error::${PM_REF%%@*}@$PM_DIGEST does not resolve"; exit 1; }
  elif command -v crane >/dev/null 2>&1; then
    crane manifest "${PM_REF%%@*}@$PM_DIGEST" >/dev/null || { echo "::error::${PM_REF%%@*}@$PM_DIGEST does not resolve"; exit 1; }
  else
    echo "::error::cannot verify: neither docker nor crane is installed (verify: false to skip)"; exit 1
  fi
fi

dir="$RUNNER_TEMP/pipemesh-produces-$PM_KEY"
mkdir -p "$dir"
python3 - "$dir/outputs.jsonl" <<'PY'
import json, os, sys
with open(sys.argv[1], "w") as f:
    f.write(json.dumps({"key": os.environ["PM_KEY"], "type": os.environ["PM_TYPE"],
                        "ref": os.environ["PM_REF"], "digest": os.environ["PM_DIGEST"]}) + "\n")
PY
echo "dir=$dir" >> "$GITHUB_OUTPUT"
echo "[pipemesh] $PM_KEY: $PM_TYPE $PM_REF ($PM_DIGEST)"
