# GitLab + Hatchet deployment-orchestration demo

Local demo scaffold for:

- GitLab as source/control/human UI
- Hatchet as durable execution
- GitLab Runner as CI execution
- GitLab Job Inputs as typed parameters for manual jobs

## 1. Start GitLab

```bash
docker compose up -d gitlab
```

Watch startup:

```bash
docker logs -f demo-gitlab
```

Check readiness:
    
```bash
curl http://localhost:8080/-/health
```

Open `http://localhost:8080`.

Get the initial root password:

```bash
docker exec demo-gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

The first initialization can take several minutes.

## 2. Create the demo project

In GitLab create a blank project named `deployment-demo`.

Copy `demo-project/.gitlab-ci.yml` into the repository and push it.

## 3. Create/register a Runner

In GitLab: Admin Area -> CI/CD -> Runners. Create an instance/group/project
runner and copy its `glrt-...` authentication token.

Then:

```bash
docker exec -it demo-gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "http://gitlab/" \
  --token "glrt-REPLACE_ME" \
  --executor "docker" \
  --description "demo-docker-runner" \
  --docker-image "alpine:3.22"
```

Verify:

```bash
docker exec demo-gitlab-runner gitlab-runner verify
```

The runner configuration persists in the named volume.

## 4. Start Hatchet locally

Install the Hatchet CLI, then run:

```bash
hatchet server start --disable-auth
```

This is the simplest local full-stack Hatchet setup for the architecture demo.

## 5. Manual job API demo

The included pipeline contains a manual `deploy_gate` job with typed inputs.
After a pipeline has been created, find the job ID and call:

```bash
export GITLAB_URL=http://localhost:8080
export GITLAB_TOKEN=REPLACE_ME
export PROJECT_ID=1
export JOB_ID=123
export DEPLOYMENT_ID=dep-demo-001
export ENVIRONMENT=staging
export STATE_VERSION=17
export ARTIFACT_VERSION=v0.1.0

./scripts/play-manual-job.sh
```

The API endpoint is:

`POST /projects/:id/jobs/:job_id/play`

with `job_inputs`.

## Architecture target

```text
GitLab pipeline
    |
    v
Hatchet workflow
    |
    v
long-running activity
    |
    v
verify durable state
    |
    v
GitLab jobs/:id/play + job_inputs
    |
    v
GitLab Runner
    |
    v
deployment step
```

Important: job inputs are parameters, not the source of truth. The deployment
job should verify the durable deployment state before performing side effects.
That makes an early human click safe: an invalid transition is rejected/no-op'd.

## Why Hatchet is not in compose.yaml yet

For the first demo, Hatchet is deliberately started through its documented
local CLI. This keeps GitLab startup/debugging independent from Hatchet. Once
the GitLab + Runner + Job Inputs path works, Hatchet can be added as a
production-like Docker Compose stack.

## Version notes

- GitLab CE: 19.4.1-ce.0
- GitLab Runner: 18.10.1
- Job Inputs: GitLab 18.10+

The GitLab Runner image is intentionally pinned rather than using `latest`.
