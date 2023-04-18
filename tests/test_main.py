# -----------------------------------------------------------------------------
# test_main.py
# copyright cfm
#
# project:  data-ms-primebrokerage
# author:   msalor
# created:  2023-04-18
#
# unit tests for main
# -----------------------------------------------------------------------------

from data_ms_primebrokerage import __version__  # noqa


def test_version_not_empty():
    assert __version__
