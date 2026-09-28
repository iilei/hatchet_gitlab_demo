#!/bin/sh
set -eu

umask 077

echo "==> Installing dependencies"
apk add --no-cache curl jq

API="${GITLAB_URL}/api/v4"
AUTH_HEADER="PRIVATE-TOKEN: ${GITLAB_BOOTSTRAP_TOKEN}"

curl_api() {
  curl \
    --silent \
    --show-error \
    --fail-with-body \
    --retry 5 \
    --retry-delay 2 \
    --retry-connrefused \
    --connect-timeout 5 \
    --max-time 30 \
    "$@"
}

# ------------------------------------------------------------
# GitLab readiness
# ------------------------------------------------------------

echo "==> Waiting for GitLab API"

until curl_api \
  --header "${AUTH_HEADER}" \
  "${API}/user" >/dev/null; do
  echo "    GitLab API not ready yet..."
  sleep 2
done

echo "==> GitLab API is ready"

# ------------------------------------------------------------
# Project
# ------------------------------------------------------------

echo "==> Looking for project: ${DEMO_PROJECT_PATH}"

PROJECT_RESPONSE="$(
  curl_api \
    --header "${AUTH_HEADER}" \
    --get \
    --data-urlencode "search=${DEMO_PROJECT_PATH}" \
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
    curl_api \
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
    echo "${PROJECT_RESPONSE}" |
      jq -r '.id'
  )"
else
  echo "==> Project already exists"
fi


if [ -z "${PROJECT_ID}" ] || [ "${PROJECT_ID}" = "null" ]; then
  echo "ERROR: Could not determine project ID"
  exit 1
fi

echo "==> Project ID: ${PROJECT_ID}"

# ------------------------------------------------------------
# CI configuration
# ------------------------------------------------------------

echo "==> Updating .gitlab-ci.yml"

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

curl_api \
  --request PUT \
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

echo "==> CI configuration updated"

# ------------------------------------------------------------
# Project Runner
# ------------------------------------------------------------

echo "==> Looking for project runner: ${GITLAB_RUNNER_DESCRIPTION}"

RUNNER_RESPONSE="$(
  curl_api \
    --header "${AUTH_HEADER}" \
    --get \
    "${API}/projects/${PROJECT_ID}/runners"
)"

RUNNER_ID="$(
  echo "${RUNNER_RESPONSE}" |
    jq -r \
      --arg description "${GITLAB_RUNNER_DESCRIPTION}" \
      '.[] | select(.description == $description) | .id' |
    head -n 1
)"

CONFIG_FILE="/runner-config/config.toml"

if [ -n "${RUNNER_ID}" ]; then
  echo "==> Project runner already exists: ${RUNNER_ID}"

  if [ ! -f "${CONFIG_FILE}" ]; then
    echo "ERROR: Runner exists in GitLab, but local runner config is missing"
    exit 1
  fi

  echo "==> Keeping existing runner configuration"

else
  echo "==> Creating project runner"

  RUNNER_RESPONSE="$(
    curl_api \
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
    exit 1
  fi

  echo "==> Runner created: ${GITLAB_RUNNER_DESCRIPTION}"

  # ----------------------------------------------------------
  # Runner config
  # ----------------------------------------------------------

  CONFIG_TMP="${CONFIG_FILE}.tmp"

  cat > "${CONFIG_TMP}" <<RUNNER_CONFIG
concurrent = 2
check_interval = 3
request_concurrency = 2

[[runners]]
  name = "${GITLAB_RUNNER_DESCRIPTION}"
  url = "${GITLAB_URL}"
  token = "${RUNNER_TOKEN}"
  executor = "docker"
  clone_url = "http://demo-gitlab"

  [runners.docker]
    image = "alpine:3.22"
    privileged = false
    pull_policy = ["if-not-present"]
    network_mode = "demo-network"
    volumes = ["/cache"]
RUNNER_CONFIG

  chmod 600 "${CONFIG_TMP}"
  mv "${CONFIG_TMP}" "${CONFIG_FILE}"

  echo "==> Runner configuration written"
fi

echo "==> Bootstrap complete"
