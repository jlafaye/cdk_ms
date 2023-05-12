import pandas as pd
from datetime import date

from data_ms_primebrokerage.libs.process import add_cfm_columns, get_deltas


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


def test_add_dates():
    df = pd.DataFrame({
        "DATE": [date(2023, 5, 11), date(2023, 5, 12)],
        "VALUE": [1, 2]
    })
    add_cfm_columns(df, delivery_type='W', date_type='HIST')
    assert all(df.CFM_ADJUST_DATE.dt.date == date(2023, 5, 15))
    df = pd.DataFrame({
        "DATE": [date(2023, 5, 11), date(2023, 5, 12)],
        "VALUE": [1, 2]
    })
    add_cfm_columns(df, delivery_type='D', date_type='HIST')
    assert df.CFM_ADJUST_DATE.dt.date[0] == date(2023, 5, 12)
    assert df.CFM_ADJUST_DATE.dt.date[1] == date(2023, 5, 15)
