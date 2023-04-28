from typing import Any

from aws_cdk import (
    aws_iam as iam,
    Stack,
)
from aws_dl_utils.dl_output.dl_commons_output import DlCommonsOutput
from aws_dl_utils.dl_output.dl_producers_output import DlProducersOutput
from aws_dl_utils.infra_output.infra_network_output import InfraNetworkOutput
from aws_dl_utils.infra_output.infra_security_output import InfraSecurityOutput
from aws_dl_utils.models.cdk_config import CdkConfig
from aws_dl_utils.models.cdk_output import (
    BucketOutput,
    KmsKeyOutput,
)
from constructs import Construct

from cdk_ms_primebrokerage.components.lambdas.infrastructure import LambdasComponent


class DataPipelineStack(Stack):
    def __init__(
        self,
        scope: Construct,
        id_: str,
        *,
        cdk_config: CdkConfig,
        **kwargs: Any,
    ) -> None:
        super().__init__(scope=scope, id=id_, **kwargs)

        infra_network_stack_output = InfraNetworkOutput(construct=self)
        vpc = infra_network_stack_output.vpc_main.this
        private_subnets = infra_network_stack_output.vpc_main.private_subnets
        public_subnets = infra_network_stack_output.vpc_main.public_subnets

        infra_security_stack_output = InfraSecurityOutput(construct=self)
        cfm_security_vault_user: iam.IUser = infra_security_stack_output.iam_user_vault.this

        dl_commons_output = DlCommonsOutput(construct=self)
        bucket_packages: BucketOutput = dl_commons_output.bucket_packages
        kms_key_s3: KmsKeyOutput = dl_commons_output.kms_key_s3

        dl_producers_output = DlProducersOutput(construct=self)
        bucket_emr_logs: BucketOutput = dl_producers_output.bucket_emr_logs
        bucket_raw: BucketOutput = dl_producers_output.bucket_raw
        bucket_silver: BucketOutput = dl_producers_output.bucket_silver
        bucket_gold: BucketOutput = dl_producers_output.bucket_gold


        lambdas = LambdasComponent(
            scope=self,
            id_="Lambdas",
            cdk_config=cdk_config,
            bucket_raw=bucket_raw,
            bucket_gold=bucket_gold,
            kms_key_s3=kms_key_s3,
            vpc=vpc,
            public_subnets=private_subnets,
        )

