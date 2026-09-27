from workflows.deployment import deployment_workflow
from hatchet_client import hatchet


def main() -> None:
    worker = hatchet.worker(
        "deployment-worker",
        workflows=[deployment_workflow],
    )

    worker.start()


if __name__ == "__main__":
    main()
