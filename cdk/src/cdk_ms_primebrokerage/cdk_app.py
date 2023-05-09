#!/usr/bin/env python3
import os
from pathlib import Path

import aws_cdk as cdk
import cfm_cdk_utils_v2.utils.cfm_global_constants as cfm_global_constants
from aws_dl_utils.models.cdk_config import CdkAppConfig
from cfm_cdk_utils_v2.utils.cfm_team_constants import CfmTeam

from cdk_ms_primebrokerage.stacks.data_pipeline import DataPipelineStack


def main():
    app = cdk.App()

    root_path = os.environ["ROOT_FOLDER"]
    env = os.environ["CFM_AWS_ENVIRONMENT"]

    cdk_app_config = CdkAppConfig(
        cfm_team=CfmTeam.DataFinancial,
        application_name="ms-primebrokerage",
        app_package_name="data_ms_primebrokerage",
        src_path=Path(root_path, "src"),
        build_path=Path(root_path, "build"),
    )

    DataPipelineStack(
        scope=app,
        id_=f"DataPipelineStack-{cdk_app_config.application_name_titled}",
        app_config=cdk_app_config,
        cfm_environment=cfm_global_constants.CfmEnvironmentEnum(env),
    )

    app.synth(validate_on_synthesis=True)


if __name__ == "__main__":
    main()
