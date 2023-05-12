from typing import Literal, Optional
import pandas as pd
from pandas.tseries.offsets import BDay, Hour, Week
from datetime import date, datetime
import re
from data_ms_primebrokerage.libs.check import check_count_dates, check_fields, check_older_file, check_values
from data_ms_primebrokerage.libs.settings import FTYPES, settings
from data_ms_primebrokerage.libs.error import AssertCollector
import awswrangler
from awswrangler.exceptions import NoFilesFound
import logging
import pytz


logging.basicConfig(
    level=logging.INFO,
)


log = logging.getLogger('data_ms_primebrokerage')


def extract_sector_region_from_fname(fname: str) -> Literal["NorthAmerica", "Europe"]:
    region_re = re.compile(r"Exposures-(NorthAmerica|Europe)\.\d{8}")
    return region_re.findall(fname)[0]


def extract_fdate_from_fname(fname: str) -> date:
    fdate_re = re.compile(r"\.(\d{8})\.")
    fdates = fdate_re.findall(fname)
    assert len(fdates) == 1
    return pd.to_datetime(fdates[0]).to_pydatetime().date()


def extract_insert_timestamp_from_fname(fname: str) -> datetime:
    fdate_re = re.compile(r"\d{8}\.(\d+)\.csv")
    fdates = fdate_re.findall(fname)
    assert len(fdates) == 1
    out = datetime.fromtimestamp(int(fdates[0]), pytz.timezone('Europe/Paris'))
    log.info(f'{out} was the inserted timestamp on s3')
    return out


def pct_to_num(serie: pd.Series):
    return serie.str.rstrip("%").astype(float)/100


def extract_ftype_from_fname(fname: str) -> FTYPES:
    for ftype in FTYPES.__args__:
        if ftype in fname:
            return ftype
    raise ValueError(f"{fname} does not match {FTYPES.__args__}")


def add_cfm_columns(
    df: pd.DataFrame,
    delivery_type: Literal['W', 'D'],
    date_type: Literal['PIT', 'HIST', 'REPLAY'],
    bday_lag: int = 1,
    hours_lag: int = 9,
    insert_date: Optional[datetime] = None,
    fdate: Optional[date] = None,
):
    " Add generic CFM dates for point in time | Add IN PLACE "
    df['CFM_INSERT_DATE'] = datetime.now(pytz.timezone('Europe/Paris'))
    df["CFM_DATE_TYPE"] = date_type.replace('REPLAY', 'HIST')
    df["DATE"] = pd.to_datetime(df.DATE)
    if date_type == "PIT":
        df["CFM_ADJUST_DATE"] = pd.NaT
    elif date_type == "HIST":
        if delivery_type == 'W':
            # For weekly delivery we transform the value date to friday
            df["CFM_ADJUST_DATE"] = df["DATE"].where(
                df["DATE"].dt.weekday == 4,
                df["DATE"] + Week(weekday=4)
            )
            # And add one BDay to make it Monday
            df["CFM_ADJUST_DATE"] = df['CFM_ADJUST_DATE'] + BDay(bday_lag) + Hour(hours_lag)
        elif delivery_type == 'D':
            df["CFM_ADJUST_DATE"] = df['DATE'] + BDay(bday_lag) + Hour(hours_lag)
        else:
            raise NotImplementedError()
    elif date_type == "REPLAY":
        if insert_date is not None:
            log.info(f'Using insert date - {insert_date}')
            df["CFM_ADJUST_DATE"] = insert_date
        else:
            assert fdate is not None
            log.info(f'Using date fdate - {fdate}')
            df["CFM_ADJUST_DATE"] = fdate + BDay(bday_lag) + Hour(hours_lag)


def get_deltas(
    existing_df: pd.DataFrame,
    incoming_df: pd.DataFrame
) -> pd.DataFrame:
    """Return the new rows in incoming_df that are not in existing_df.
    To identify duplicates, only columns that do not start with CFM_ are looked at"""
    check_cols = set(existing_df.columns) - set(incoming_df.columns)
    assert len(check_cols) == 0, f'Missing columns in incoming dataframe {check_cols}'
    cols = [c for c in incoming_df.columns if not c.startswith('CFM_')]
    out = (
        pd.concat([
            existing_df.assign(SRC="existing"),
            incoming_df.assign(SRC="incoming")
        ], axis=0)
        .drop_duplicates(subset=cols, keep='first')
        .query("SRC=='incoming'")
        .drop('SRC', axis=1)
    )
    return out


def read_csv(path: str) -> pd.DataFrame:
    " Read raw csv from provider, normalize the columns and parse dates. "
    out = awswrangler.s3.read_csv(path)
    out.columns = out.columns.str.upper()
    out.columns = out.columns.str.replace(' ', '_')
    out['DATE'] = pd.to_datetime(out['DATE'], errors='coerce')
    out.drop(
        "SOURCE:_MSCI_BARRA,_MORGAN_STANLEY_PRIME_BROKERAGE",
        axis=1,
        errors='ignore',
        inplace=True
    )
    out = out.dropna(subset=['DATE'])
    fdate = extract_fdate_from_fname(path)
    out = out.assign(CFM_FDATE=fdate)

    # Normalize these columns
    candidate_col = ['COUNTRY_NAME', 'GICS_SECTOR', 'FACTOR_TYPE']
    for col in candidate_col:
        if col in out:
            out[col] = (
                out[col]
                .str.lower()
                .str.lower()
                .str.strip()
                .str.replace(r'\s+', ' ', regex=True)  # Remove multiple spaces
            )
    return out


class Processor():
    def __init__(self, settings: dict):
        self.settings = settings

    def read_incoming(
        self,
        path_incoming: str,
        date_type: Literal["PIT", "HIST"],
    ):
        """
        Read the data from the incoming file path and add cfm dates columns.
        Extract the ftype from the path and perform further normalizing operations based on the infered ftype.
        """
        self.df_incoming = read_csv(path=path_incoming)
        self.ftype = extract_ftype_from_fname(path_incoming)

        if self.ftype == "longshort_leverage":
            hours_lag = 14
        else:
            hours_lag = 9

        insert_date = extract_insert_timestamp_from_fname(path_incoming)

        add_cfm_columns(
            self.df_incoming,
            date_type=date_type,
            delivery_type=self.settings[self.ftype].frequency,
            hours_lag=hours_lag,
            insert_date=insert_date,
            fdate=self.df_incoming.CFM_FDATE[0]
        )

        if self.ftype == 'factor_exposure':
            for col in ['FACTOR_NET_EXPOSURE', 'FACTOR_SHORT_EXPOSURE', 'FACTOR_LONG_EXPOSURE']:
                assert self.df_incoming[col].str.contains('%').all(), f'{col} should be expressed as xx.x%'
                self.df_incoming[col] = pct_to_num(self.df_incoming[col])

        if self.ftype == 'sector_exposure_north_america':
            self.df_incoming = self.df_incoming.assign(REGION='NorthAmerica')
        elif self.ftype == 'sector_exposure_europe':
            self.df_incoming = self.df_incoming.assign(REGION='Europe')

        for col in ['GROSS_LEV_AVG_EU_RA', 'NET_LEV_AVG_EU_RA']:
            if col in self.df_incoming:
                self.df_incoming[col] = pd.to_numeric(self.df_incoming[col])

    def read_existing(self):
        tables = awswrangler.catalog.tables(
            database=self.settings[self.ftype].database
        ).Table.values

        if self.settings[self.ftype].table in tables:
            self.df_existing = awswrangler.s3.read_parquet_table(
                table=self.settings[self.ftype].table,
                database=self.settings[self.ftype].database
            )
            self.df_existing.columns = self.df_existing.columns.str.upper()
        else:
            raise NoFilesFound()

    def write_output(self, output: pd.DataFrame, writting_mode: Literal["overwrite", "append"]):
        """
        Write the output dataframe to the path defined by the settings.
        Check the schema of the destination against the schema of the incoming dataframe.
        """
        path = self.settings[self.ftype].output_path
        table = self.settings[self.ftype].table
        database = self.settings[self.ftype].database
        log.info(f'Writting {output.shape} dataframe to {path}')
        try:
            if writting_mode == 'append':
                schema = awswrangler.s3.read_parquet_metadata(path)[0]
                log.info(f'Read from path {path}')
                assert all([col in output.columns.str.lower() for col in schema.keys()])
        except NoFilesFound:
            pass
        log.info(f'Write in mode {writting_mode}')
        awswrangler.s3.to_parquet(
            output,
            path,
            partition_cols=[],
            dataset=True,
            table=table,
            database=database,
            mode=writting_mode
        )

    def run(
        self,
        path_incoming: str,
        date_type: Literal["PIT", "HIST", "REPLAY"],
        writting_mode: Literal["overwrite", "append"]
    ):
        """
        Run the entire process.
        * Read incoming data
        * Read existing data
        * Compute deltas
        * Concatenate deltas and existing
        * Write the output.
        """
        log.info(f'Start processing {path_incoming}')
        self.read_incoming(path_incoming=path_incoming, date_type=date_type)
        try:
            if writting_mode == 'overwrite':
                raise NoFilesFound()
            self.read_existing()
            check_older_file(
                df_existing=self.df_existing,
                df_incoming=self.df_incoming,
                ftype=self.ftype
            )
            deltas = get_deltas(
                incoming_df=self.df_incoming,
                existing_df=self.df_existing
            )

            AssertCollector().do_assert(
                len(deltas.DATE.unique()) < 21,
                f"We received updates on more than 21 days - {len(deltas.DATE.unique())}"
            )

            log.info(f'Found {deltas.shape} deltas')
            out = pd.concat([self.df_existing, deltas], axis=0)
        except NoFilesFound:
            log.info('No existing files')
            out = self.df_incoming
            deltas = pd.DataFrame()
            self.write_output(out, writting_mode)

        if not deltas.empty:
            self.write_output(deltas, writting_mode)

            check_values(out)
            check_count_dates(out, self.settings[self.ftype].frequency)
            check_fields(out)

        if date_type == 'PIT':
            AssertCollector().raise_all()


def check_nan(df: pd.DataFrame, ndates: int):
    max_dts = sorted(df.DATE.unique())[-ndates:]
    assert not df.loc[df.DATE.isin(max_dts)].isna().any().any(), "We should have no NaN in the DataFrame"


def process(
    fname: str,
    date_type: Literal['HIST', 'PIT', 'REPLAY'],
    writting_mode: str = 'append'
):
    processor = Processor(settings=settings)
    processor.run(fname, date_type=date_type, writting_mode=writting_mode)


def process_histo():
    for directory in awswrangler.s3.list_directories('s3://cfm-financial-raw-dev/morganstanley/primebrokerage/'):
        mode = 'overwrite'
        date_mode = 'HIST'
        objects = sorted(awswrangler.s3.list_objects(directory))
        for obj in objects:
            try:
                process(obj, date_mode, writting_mode=mode)
                date_mode = 'REPLAY'
                mode = 'append'
            except AssertionError as e:
                print(e)
                continue


def compact_dataset(path: str):
    " Compact the dataset at a given path "
    df = awswrangler.s3.read_parquet(path)
    awswrangler.s3.to_parquet(df, path, mode='overwrite', partition_cols=[], dataset=True)
