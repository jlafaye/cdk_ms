from typing import (
    Any,
    Dict,
)
import data_ms_primebrokerage.libs.process as process
from data_ms_primebrokerage.libs.settings import settings


def handler(event: Dict[str, Any], context: Any) -> Dict:
    for k, v in settings.items():
        process.compact_dataset(v.output_path)

    return {"message": "ok"}
