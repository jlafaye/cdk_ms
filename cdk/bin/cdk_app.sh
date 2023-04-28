#!/bin/env bash

export ROOT_FOLDER="$(pwd)"
export PYTHONPATH="${ROOT_FOLDER}/src:${ROOT_FOLDER}/..:${PYTHONPATH}"

python -m cdk_ms_primebrokerage.cdk_app
