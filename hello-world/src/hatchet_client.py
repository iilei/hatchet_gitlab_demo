from hatchet_sdk import Hatchet
from hatchet_sdk.config import ClientTLSConfig, ClientConfig


hatchet = Hatchet(
    config=ClientConfig(
        tls_config=ClientTLSConfig(
            strategy="insecure",
        ),
    )
)
