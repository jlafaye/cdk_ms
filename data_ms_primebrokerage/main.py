from typing import (
    Any,
    Dict,
)
import data_ms_primebrokerage.libs.process as process
from data_ms_primebrokerage.libs.settings import settings


def handler(event: Dict[str, Any], context: Any) -> Dict:
    for record in event['Records']:
        event_src_bucket = record['s3']['bucket']['name']
        event_src_key = record['s3']['object']['key']

        file_path = f"s3://{event_src_bucket}/{event_src_key}"
        print(f"File being processed :: {file_path}")
        process.process(file_path, 'PIT')

    return {"message": "ok"}


def handler_compact(event: Dict[str, Any], context: Any) -> Dict:
    for k, v in settings.items():
        process.compact_dataset(v.output_path)

    return {"message": "ok"}
