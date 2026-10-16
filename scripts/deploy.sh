#!/usr/bin/env bash
# Usage: deploy.sh <container-name> <host-port> <image>
# Replaces a running container with a new image, smoke tests it,
# and restores the previous image if the new one is unhealthy.
set -euo pipefail

NAME="${1:?container name required}"
PORT="${2:?host port required}"
IMAGE="${3:?image required}"
NETWORK="${NETWORK:-cicd}"
HERE="$(cd "$(dirname "$0")" && pwd)"

run_container() {
  docker run -d --name "$NAME" --network "$NETWORK" \
    -p "${PORT}:8000" --restart unless-stopped "$1" > /dev/null
}

PREVIOUS="$(docker inspect -f '{{.Config.Image}}' "$NAME" 2>/dev/null || true)"

docker rm -f "$NAME" > /dev/null 2>&1 || true
echo "Deploying $IMAGE as $NAME on port $PORT"
run_container "$IMAGE"

if "$HERE/smoke_test.sh" "$NAME"; then
  echo "Deploy succeeded: $NAME is running $IMAGE"
  exit 0
fi

echo "Smoke test FAILED for $IMAGE" >&2
docker logs --tail 50 "$NAME" >&2 || true
docker rm -f "$NAME" > /dev/null 2>&1 || true

if [ -n "$PREVIOUS" ]; then
  echo "Rolling back to $PREVIOUS" >&2
  run_container "$PREVIOUS"
else
  echo "No previous version to roll back to" >&2
fi
exit 1
