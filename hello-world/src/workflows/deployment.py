from hatchet_sdk import Context
from pydantic import BaseModel

from hatchet_client import hatchet


class DeploymentInput(BaseModel):
    environment: str
    version: str


class DeployResult(BaseModel):
    deployment_id: str
    environment: str
    version: str


class VerifyResult(BaseModel):
    deployment_id: str
    verified: bool


class FinishResult(BaseModel):
    deployment_id: str
    status: str


deployment_workflow = hatchet.workflow(
    name="deployment-workflow",
    input_validator=DeploymentInput,
)


@deployment_workflow.task()
def deploy(
    input: DeploymentInput,
    ctx: Context,
) -> DeployResult:
    print(
        f"Deploying {input.version} "
        f"to {input.environment}"
    )

    deployment_id = f"{input.environment}-{input.version}"

    return DeployResult(
        deployment_id=deployment_id,
        environment=input.environment,
        version=input.version,
    )


@deployment_workflow.task(parents=[deploy])
def verify(
    input: DeploymentInput,
    ctx: Context,
) -> VerifyResult:
    result = ctx.task_output(deploy)

    print(f"Verifying deployment {result.deployment_id}")

    return VerifyResult(
        deployment_id=result.deployment_id,
        verified=True,
    )


@deployment_workflow.task(parents=[verify])
def finish(
    input: DeploymentInput,
    ctx: Context,
) -> FinishResult:
    result = ctx.task_output(verify)

    status = "success" if result.verified else "failed"

    print(
        f"Deployment {result.deployment_id}: "
        f"{status}"
    )

    return FinishResult(
        deployment_id=result.deployment_id,
        status=status,
    )
