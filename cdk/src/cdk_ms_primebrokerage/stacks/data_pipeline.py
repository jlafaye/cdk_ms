from typing import Any

import cfm_cdk_utils_v2.utils.cfm_global_constants as cfm_global_constants
from aws_dl_utils.dl_output.dl_commons_output import DlCommonsOutput
from aws_dl_utils.dl_output.dl_producers_output import DlProducersOutput
from aws_dl_utils.infra_output.infra_network_output import InfraNetworkOutput
from aws_dl_utils.models.cdk_config import CdkAppConfig
from aws_dl_utils.models.cdk_output import (
    BucketOutput,
    KmsKeyOutput,
)
from aws_dl_utils.models.dl_stack import DlBaseStack
from constructs import Construct

from cdk_ms_primebrokerage.components.lambdas.infrastructure import LambdasComponent


class DataPipelineStack(DlBaseStack):
    def __init__(
        self,
        scope: Construct,
        id_: str,
        *,
        app_config: CdkAppConfig,
        cfm_environment: cfm_global_constants.CfmEnvironmentEnum,
        **kwargs: Any,
    ) -> None:
        super().__init__(
            scope=scope,
            id_=id_,
            cdk_app_config=app_config,
            cfm_environment=cfm_environment,
            **kwargs,
        )

        infra_network_stack_output = InfraNetworkOutput(construct=self)
        vpc = infra_network_stack_output.vpc_main.this
        private_subnets = infra_network_stack_output.vpc_main.private_subnets

        dl_commons_output = DlCommonsOutput(construct=self)
        kms_key_s3: KmsKeyOutput = dl_commons_output.kms_key_s3
        dl_producers_output = DlProducersOutput(construct=self)
        bucket_raw: BucketOutput = dl_producers_output.bucket_raw
        bucket_gold: BucketOutput = dl_producers_output.bucket_gold

        LambdasComponent(
            scope=self,
            id_="Lambdas",
            app_config=app_config,
            bucket_raw=bucket_raw,
            bucket_gold=bucket_gold,
            kms_key_s3=kms_key_s3,
            vpc=vpc,
            public_subnets=private_subnets,
            env=self.stack_config.env,
        )
