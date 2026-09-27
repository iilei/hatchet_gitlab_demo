#!/usr/bin/env sh
set -eu

: "${GITLAB_URL:?set GITLAB_URL, e.g. http://localhost:8080}"
: "${GITLAB_TOKEN:?set GITLAB_TOKEN}"
: "${PROJECT_ID:?set PROJECT_ID}"
: "${JOB_ID:?set JOB_ID}"

curl --fail-with-body \
  --request POST \
  --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  --header "Content-Type: application/json" \
  --data "{
    \"job_inputs\": {
      \"deployment_id\": \"${DEPLOYMENT_ID:-dep-demo-001}\",
      \"environment\": \"${ENVIRONMENT:-staging}\",
      \"state_version\": ${STATE_VERSION:-17},
      \"artifact_version\": \"${ARTIFACT_VERSION:-v0.1.0}\"
    }
  }" \
  "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/jobs/${JOB_ID}/play"
