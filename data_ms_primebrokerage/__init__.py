# -----------------------------------------------------------------------------
# __init__.py
# copyright cfm
#
# project:  data-ms-primebrokerage
# author:   msalor
# created:  2023-04-18
#
# 
# -----------------------------------------------------------------------------

from importlib.metadata import version, PackageNotFoundError

try:
    __version__ = version('data_ms_primebrokerage')
except PackageNotFoundError:
    __version__ = '0.0.0'

__author__ = 'msalor'
