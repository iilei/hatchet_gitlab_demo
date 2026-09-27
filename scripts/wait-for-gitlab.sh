#!/usr/bin/env sh
set -eu
URL="${1:-http://localhost:8080/-/health}"
echo "Waiting for GitLab: ${URL}"
i=0
while [ "$i" -lt 60 ]; do
  if curl --fail --silent "$URL" >/dev/null; then
    echo "GitLab is ready."
    exit 0
  fi
  i=$((i + 1))
  sleep 5
done
echo "GitLab did not become ready in time." >&2
exit 1
