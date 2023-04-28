#!/usr/bin/env python3
import os
from pathlib import Path

import aws_cdk as cdk
from aws_dl_utils.models.cdk_config import CdkConfig
from cfm_cdk_utils_v2.aspects.cfm_tags_adding_aspect import CfmTagsAddingAspect
from cfm_cdk_utils_v2.utils.cfm_team_constants import CfmTeam

from cdk_ms_primebrokerage.stacks.data_pipeline import DataPipelineStack

def main():
    app = cdk.App()

    if "CDK_DEPLOY_ACCOUNT" not in os.environ and "CDK_DEFAULT_ACCOUNT" not in os.environ:
        raise ValueError("You must define either CDK_DEPLOY_ACCOUNT or CDK_DEFAULT_ACCOUNT in the environment.")
    if "CDK_DEPLOY_REGION" not in os.environ and "CDK_DEFAULT_REGION" not in os.environ:
        raise ValueError("You must define either CDK_DEPLOY_REGION or CDK_DEFAULT_REGION in the environment.")

    account_id = os.environ.get("CDK_DEPLOY_ACCOUNT", os.environ.get("CDK_DEFAULT_ACCOUNT"))
    region = os.environ.get("CDK_DEPLOY_REGION", os.environ.get("CDK_DEFAULT_REGION", "eu-west-1"))
    cdk_environment = cdk.Environment(account=account_id, region=region)

    root_path = os.environ["ROOT_FOLDER"]

    cdk_config = CdkConfig(
        account_id=account_id,
        region=region,
        cfm_team=CfmTeam.DataFinancial,
        application_name="ms-primebrokerage",
        app_package_name="data_ms_primebrokerage",
        src_path=Path(root_path, "src"),
        build_path=Path(root_path, "build"),
        tags={},
    )

    env = os.environ["CFM_AWS_ENVIRONMENT"]

    cdk.Aspects.of(app).add(
        CfmTagsAddingAspect(
            env=env,
            cfm_team=cdk_config.cfm_team,
            application_name=cdk_config.application_name,
        )
    )

    DataPipelineStack(
        scope=app,
        id_=f"DataPipelineStack-{cdk_config.application_name_titled}",
        env=cdk_environment,
        cdk_config=cdk_config,
    )

    app.synth()


if __name__ == "__main__":
    main()
