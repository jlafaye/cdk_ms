import os
from importlib import import_module
from typing import (
    Any,
    Dict,
)


def lambda_handler(event: Dict[str, Any], context: Any) -> str:
    app_name = os.environ["APP_PACKAGE"]

    lambdas = import_module(f"{app_name}.main")

    handler = getattr(lambdas, "handler")
    return handler(event, context)
