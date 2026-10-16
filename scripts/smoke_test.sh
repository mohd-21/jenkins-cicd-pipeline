#!/usr/bin/env bash
# Usage: smoke_test.sh <container-name>
# Calls /health from inside the same Docker network, retrying while the app starts.
set -euo pipefail

NAME="${1:?container name required}"
NETWORK="${NETWORK:-cicd}"

docker run --rm --network "$NETWORK" curlimages/curl:8.8.0 \
  -fsS --retry 10 --retry-delay 2 --retry-connrefused \
  "http://${NAME}:8000/health"
echo
