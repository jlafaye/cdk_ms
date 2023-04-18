REPOSITORY_SPACE=it-data-platform/ENVIRONMENT_VERSION
REPOSITORY_USER=it-data-platform
TEST_SOURCES=tests

ENVIRONMENT_VERSION?=2201
APM_CONDA_CHANNELS=it_data_platform_2201 cfm_common

FLAKE8_OPTIONS=--max-line-length=120
PYTEST_OPTIONS= -v -s  --doctest-modules
