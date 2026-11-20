#!/usr/bin/env bash
# Where this run pushes the image of an oci key its Pipemesh job declares:
# the key's place in Pipemesh's registry under the job run's own tag
# (DESIGN-V142 §3). The run proves who it is with its own GitHub OIDC token,
# as pipemesh/consume does. Nothing is emitted: when the run succeeds,
# Pipemesh records the image the registry holds there under that tag.
set -euo pipefail

if ! [[ "$PM_KEY" =~ ^[A-Za-z0-9_-]+$ ]]; then echo "::error::key '$PM_KEY' must be letters, digits, _ and -"; exit 1; fi
if [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
  echo "::error::pipemesh/produce with place: true needs an OIDC token: add 'permissions: { id-token: write }' to the job"
  exit 1
fi
if [ -z "${PM_RUN:-}" ]; then
  echo "::error::no pipemesh_run — this workflow must be dispatched by Pipemesh and declare the pipemesh_run input"
  exit 1
fi

urlencode() { python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }
PM_URL=${PM_URL%/}
token=$(curl -fsS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=$(urlencode "$PM_URL")" \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["value"])')
echo "::add-mask::$token"

answer=$(mktemp)
trap 'rm -f "$answer"' EXIT
code=$(curl -sS -o "$answer" -w '%{http_code}' -X POST -H "Authorization: Bearer $token" \
  "$PM_URL/api/runtime/actions/images/place?run=$(urlencode "$PM_RUN")&key=$(urlencode "$PM_KEY")" || echo 000)
if [ "$code" != 200 ]; then
  echo "::error::Pipemesh refused a place for $PM_KEY (HTTP $code): $(cat "$answer" 2>/dev/null)"
  exit 1
fi
ref=$(tr -d '\r\n' < "$answer")
echo "ref=$ref" >> "$GITHUB_OUTPUT"
echo "[pipemesh] $PM_KEY: push to $ref"
