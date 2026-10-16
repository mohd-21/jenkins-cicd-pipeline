#!/usr/bin/env bash
# One-time SonarQube setup: waits until it is up, replaces the default admin password,
# creates an analysis token, and registers the webhook the Jenkins quality gate needs.
#
# Usage: SONAR_NEW_PASSWORD='a-strong-password' scripts/bootstrap-sonarqube.sh
# Prints the token; put it in .env as SONAR_TOKEN and run `docker compose up -d jenkins`.
set -euo pipefail

SONAR_URL="${SONAR_URL:-http://localhost:9000}"
NEW_PASSWORD="${SONAR_NEW_PASSWORD:?set SONAR_NEW_PASSWORD}"
JENKINS_WEBHOOK="${JENKINS_WEBHOOK:-http://jenkins:8080/sonarqube-webhook/}"

echo "Waiting for SonarQube at $SONAR_URL (first start can take a few minutes)..."
for _ in $(seq 1 90); do
  if curl -fsS "$SONAR_URL/api/system/status" | grep -q '"status":"UP"'; then break; fi
  sleep 5
done
curl -fsS "$SONAR_URL/api/system/status" | grep -q '"status":"UP"' || { echo "SonarQube did not start" >&2; exit 1; }

# The default login is admin/admin; change it first. Ignore the error if already changed.
curl -sS -u admin:admin -X POST "$SONAR_URL/api/users/change_password" \
  --data-urlencode "login=admin" \
  --data-urlencode "previousPassword=admin" \
  --data-urlencode "password=$NEW_PASSWORD" > /dev/null || true

TOKEN="$(curl -fsS -u "admin:$NEW_PASSWORD" -X POST "$SONAR_URL/api/user_tokens/generate" \
  --data-urlencode "name=jenkins-$(date +%s)" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
[ -n "$TOKEN" ] || { echo "Could not create a token" >&2; exit 1; }

curl -fsS -u "admin:$NEW_PASSWORD" -X POST "$SONAR_URL/api/webhooks/create" \
  --data-urlencode "name=jenkins" \
  --data-urlencode "url=$JENKINS_WEBHOOK" > /dev/null

echo
echo "Done. Add this line to .env:"
echo "SONAR_TOKEN=$TOKEN"
