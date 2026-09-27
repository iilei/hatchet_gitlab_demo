#!/bin/sh
set -eu

echo "==> Installing dependencies"
apk add --no-cache curl jq

API="${GITLAB_URL}/api/v4"
AUTH_HEADER="PRIVATE-TOKEN: ${GITLAB_BOOTSTRAP_TOKEN}"

echo "==> GitLab is ready"

# ------------------------------------------------------------
# Project
# ------------------------------------------------------------

echo "==> Looking for project: ${DEMO_PROJECT_PATH}"

PROJECT_RESPONSE="$(
  curl \
    --silent \
    --show-error \
    --header "${AUTH_HEADER}" \
    --get \
    --data-urlencode "search=${DEMO_PROJECT_NAME}" \
    "${API}/projects"
)"

PROJECT_ID="$(
  echo "${PROJECT_RESPONSE}" |
    jq -r \
      --arg path "${DEMO_PROJECT_PATH}" \
      '.[] | select(.path == $path) | .id' |
    head -n 1
)"

if [ -z "${PROJECT_ID}" ]; then

  echo "==> Creating project"

  PROJECT_RESPONSE="$(
    curl \
      --silent \
      --show-error \
      --fail-with-body \
      --request POST \
      --header "${AUTH_HEADER}" \
      --header "Content-Type: application/json" \
      --data "$(
        jq -n \
          --arg name "${DEMO_PROJECT_NAME}" \
          --arg path "${DEMO_PROJECT_PATH}" \
          '{
            name: $name,
            path: $path,
            visibility: "private",
            initialize_with_readme: true
          }'
      )" \
      "${API}/projects"
  )"

  PROJECT_ID="$(
    echo "${PROJECT_RESPONSE}" | jq -r '.id'
  )"

else

  echo "==> Project already exists"

fi

if [ -z "${PROJECT_ID}" ] || [ "${PROJECT_ID}" = "null" ]; then
  echo "ERROR: Could not determine project ID"
  echo "${PROJECT_RESPONSE:-}"
  exit 1
fi

echo "==> Project ID: ${PROJECT_ID}"

# ------------------------------------------------------------
# CI configuration
# ------------------------------------------------------------

echo "==> Creating .gitlab-ci.yml"

CI_CONFIG='
stages:
  - deploy

deploy:
  stage: deploy
  when: manual

  script:
    - echo "Starting deployment"
    - echo "Environment: ${DEPLOY_ENVIRONMENT}"
    - echo "Version: ${DEPLOY_VERSION}"
    - echo "Deployment finished"
'

curl \
  --silent \
  --show-error \
  --fail-with-body \
  --request POST \
  --header "${AUTH_HEADER}" \
  --header "Content-Type: application/json" \
  --data "$(
    jq -n \
      --arg branch "main" \
      --arg content "${CI_CONFIG}" \
      '{
        branch: $branch,
        content: $content,
        commit_message: "Bootstrap demo pipeline"
      }'
  )" \
  "${API}/projects/${PROJECT_ID}/repository/files/.gitlab-ci.yml"

echo "==> CI configuration created"

# ------------------------------------------------------------
# Runner
# ------------------------------------------------------------

echo "==> Creating project runner"

RUNNER_RESPONSE="$(
  curl \
    --silent \
    --show-error \
    --fail-with-body \
    --request POST \
    --header "${AUTH_HEADER}" \
    --header "Content-Type: application/json" \
    --data "$(
      jq -n \
        --arg description "${GITLAB_RUNNER_DESCRIPTION}" \
        --argjson project_id "${PROJECT_ID}" \
        '{
          runner_type: "project_type",
          description: $description,
          project_id: $project_id,
          run_untagged: true,
          locked: true
        }'
    )" \
    "${API}/user/runners"
)"

RUNNER_TOKEN="$(
  echo "${RUNNER_RESPONSE}" |
    jq -r '.token // empty'
)"

if [ -z "${RUNNER_TOKEN}" ]; then
  echo "ERROR: GitLab did not return a runner token"
  echo "${RUNNER_RESPONSE}"
  exit 1
fi

echo "==> Runner created"

# ------------------------------------------------------------
# Runner config
# ------------------------------------------------------------

cat > /runner-config/config.toml <<RUNNER_CONFIG
concurrent = 2
check_interval = 3
request_concurrency = 2

[[runners]]
  name = "${GITLAB_RUNNER_DESCRIPTION}"
  url = "${GITLAB_URL}"
  token = "${RUNNER_TOKEN}"
  executor = "docker"

  [runners.docker]
    image = "alpine:3.22"
    privileged = false
    pull_policy = ["if-not-present"]
    volumes = ["/cache"]
RUNNER_CONFIG

chmod 600 /runner-config/config.toml

echo "==> Runner configuration written"
echo "==> Bootstrap complete"
