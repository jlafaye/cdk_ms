import pandas as pd

from data_ms_primebrokerage.libs.process import get_deltas


def test_get_deltas():
    existing = pd.DataFrame({
        'CFM_BATCH_ID': [1, 1, 1, 1],
        'CFM_INSERT_DATE': [1] * 4,
        'VALUE': [1, 1, 1, 1],
        'KEY': list(range(4)),
    })
    incoming = pd.DataFrame({
        'CFM_BATCH_ID': [2] * 6,
        'CFM_INSERT_DATE': [2] * 6,
        'VALUE': [1, 2, 2, 1, 1, 1],
        'KEY': list(range(6)),
    })

    out = get_deltas(
        existing_df=existing,
        incoming_df=incoming
    ).reset_index(drop=True)

    expected = pd.DataFrame({
        'CFM_BATCH_ID': [2] * 4,
        'CFM_INSERT_DATE': [2] * 4,
        'VALUE': [2, 2, 1, 1],
        'KEY': [1, 2, 4, 5],
    })
    assert out.equals(expected)
