from dataclasses import dataclass
from typing import Literal
import os


@dataclass()
class FtypeSettings:
    output_path: str
    frequency: str
    database: str
    table: str


# ENV = os.environ['...']
ENV = 'dev'
DATABASE = f'financial_{ENV}_link'

settings = {
    'country_level_exposure': FtypeSettings(
        output_path='s3://cfm-financial-gold-dev/morganstanley_pb/country',
        frequency='W',
        database=DATABASE,
        table='morgan_stanley_pb_country_level_exposure'
    ),
    'regional_leverage': FtypeSettings(
        output_path='s3://cfm-financial-gold-dev/morganstanley_pb/regional_leverage',
        frequency='D',
        database=DATABASE,
        table='morgan_stanley_pb_regional_leverage'
    ),
    'sector_exposure_europe':  FtypeSettings(
        output_path='s3://cfm-financial-gold-dev/morganstanley_pb/sector_exposure_eu',
        frequency='W',
        database=DATABASE,
        table='morgan_stanley_pb_sector_exposure_europe'
    ),
    'sector_exposure_north_america':  FtypeSettings(
        output_path='s3://cfm-financial-gold-dev/morganstanley_pb/sector_exposure_na',
        frequency='W',
        database=DATABASE,
        table='morgan_stanley_pb_sector_exposure_north_america'
    ),
    'factor_exposure': FtypeSettings(
        output_path='s3://cfm-financial-gold-dev/morganstanley_pb/factor_exposure',
        frequency='W',
        database=DATABASE,
        table='morgan_stanley_pb_factor_exposure'
    ),
    'longshort_leverage': FtypeSettings(
        output_path='s3://cfm-financial-gold-dev/morganstanley_pb/long_short_leverage',
        frequency='D',
        database=DATABASE,
        table='morgan_stanley_pb_longshort_leverage'
    )
}


COUNTRIES = [
    'australia',
    'brazil',
    'canada',
    'china',
    'denmark',
    'france',
    'germany',
    'hong kong',
    'india',
    'italy',
    'japan',
    'korea, south',
    'netherlands',
    'spain',
    'sweden',
    'switzerland',
    'taiwan',
    'united kingdom',
    'united states',
    'total',
    'eurozone',
    'greater china :china',
    'greater china :hong kong',
    'greater china :united states'
]


FACTORS = [
    'beta',
    'divyield',
    'earn. qlty.',
    'earnings yield',
    'facs quality',
    'facs size',
    'facs value',
    'facs volatility',
    'growth',
    'lt rev',
    'leverage',
    'liquidity',
    'mgmt quality',
    'midcap',
    'momentum',
    'profitability',
    'prospect',
    'resvol',
    'size',
    'value'
]

GICS = [
    'utilities',
    'real estate',
    'information technology',
    'industrials',
    'health care',
    'materials',
    'communication services',
    'consumer discretionary',
    'financials',
    'etf',
    'energy',
    'consumer staples'
]


FTYPES = Literal[
    'country_level_exposure',
    'regional_leverage',
    'sector_exposure_europe',
    'sector_exposure_north_america',
    'factor_exposure',
    'longshort_leverage'
]
