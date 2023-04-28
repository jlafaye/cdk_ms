from datetime import date
from typing import Literal
from pandas.tseries.offsets import BDay, Week
import pandas as pd
from data_ms_primebrokerage.libs.settings import FACTORS, FTYPES, GICS, COUNTRIES
from data_ms_primebrokerage.libs.error import AssertCollector
import numpy as np


def check_count_dates(
    df: pd.DataFrame,
    frequency: Literal['D', 'W']
):
    " Count that for the last expected business day we have receive the expected amount of data "
    today = date.today()
    counts = df.groupby(['DATE', 'CFM_FDATE'])['CFM_FDATE'].count()
    if frequency == 'D':
        dt = today - BDay(1)
        if dt not in counts.index:
            AssertCollector().do_assert(
                False,
                f"{dt} was expected in the index but wasnt - \n {counts.iloc[-5:]}"
            )
    elif frequency == 'W':
        dt = today - Week(weekday=4)
        if dt not in counts.index:
            AssertCollector().do_assert(
                False,
                f"{dt} was expected in the index but wasnt - \n {counts.iloc[-5:]}"
            )
    else:
        raise NotImplementedError()


def check_fields(df: pd.DataFrame):
    "Check that we received all the expected fields"
    max_dt = df.DATE.max()
    df = df.loc[df.DATE == max_dt]

    if 'GICS_SECTOR' in df.columns:
        missing_gics = set(GICS) - set(df['GICS_SECTOR'])
        AssertCollector().do_assert(
            len(missing_gics) == 0,
            f"We are missing following gics sectors {missing_gics} for {max_dt}"
        )

    if 'ISO_CODE' in df.columns and 'COUNTRY_NAME' in df.columns:
        unique_iso_per_country = df.groupby('COUNTRY_NAME')['ISO_CODE'].nunique()
        AssertCollector().do_assert(
            max(unique_iso_per_country) == 1,
            f"Some countries have multiple iso code \n {unique_iso_per_country.loc[unique_iso_per_country>1]}"
        )

    if 'COUNTRY_NAME' in df.columns:
        missing_countries = set(COUNTRIES) - set(df['COUNTRY_NAME'])
        AssertCollector().do_assert(
            len(missing_countries) == 0,
            f"We are missing following country names {missing_countries} for {max_dt}"
        )

    if 'FACTOR_TYPE' in df.columns:
        missing_factors = set(FACTORS) - set(df['FACTOR_TYPE'])
        AssertCollector().do_assert(
            len(missing_factors) == 0,
            f"We are missing following Factor Type {missing_factors} for {max_dt}"
        )


def check_values(df: pd.DataFrame):
    " Performs a z-score check on all numerical values "
    cols = [c for c in df if not c.startswith('CFM_')]
    num_cols = df.select_dtypes(include=np.number).columns
    df = df.sort_values('CFM_FDATE').drop_duplicates(subset=cols, keep='last')
    grp_cols = ['DATE']
    candidate_col = ['COUNTRY_NAME', 'GICS_SECTOR', 'FACTOR_TYPE']
    for col in candidate_col:
        if col in cols:
            grp_cols.append(col)
    assert len(grp_cols) <= 2
    df = df.groupby(grp_cols)[num_cols].mean()
    if len(grp_cols) > 1:
        df = df.unstack(level=1)
    zscore = (df - df.mean()) / df.std()
    out = zscore.iloc[-1].loc[zscore.iloc[-1].abs() > 4]
    AssertCollector().do_assert(
        out.empty,
        f' Absolute z-score above 4 \n {out}'
    )


def check_older_file(
    df_incoming: pd.DataFrame,
    df_existing: pd.DataFrame,
    ftype: FTYPES
):
    "Assert that we are not processing a dataframe that has an older FDATE than the max we already processed"
    max_dt = df_existing.CFM_FDATE.max()
    incoming_dt = df_incoming.CFM_FDATE.max()
    assert max_dt < incoming_dt, f"Trying to process an older filer {incoming_dt} vs {max_dt}"
