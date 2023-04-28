from pathlib import Path
from typing import List

from aws_cdk import (
    aws_ec2 as ec2,
    aws_iam as iam,
    aws_lambda as aws_lambda,
    aws_logs as logs,
    Duration,
    RemovalPolicy,
)
from aws_cdk.aws_logs import RetentionDays
from aws_dl_utils.models.cdk_config import CdkConfig
from aws_dl_utils.models.cdk_output import (
    BucketOutput,
    KmsKeyOutput,
)
from constructs import Construct


class LambdasComponent(Construct):
    def __init__(
        self,
        scope: Construct,
        id_: str,
        *,
        cdk_config: CdkConfig,
        vpc: ec2.IVpc,
        public_subnets: List[ec2.ISubnet],
        bucket_raw: BucketOutput,
        bucket_gold: BucketOutput,
        kms_key_s3: KmsKeyOutput,
    ) -> None:
        super().__init__(scope, id_)

        lambda_name = cdk_config.application_name

        log_group = logs.LogGroup(
            scope=self,
            id="log_group",
            log_group_name=f"/aws/lambda/{lambda_name}",
            retention=RetentionDays.ONE_MONTH,
            encryption_key=kms_key_s3.this,
            removal_policy=RemovalPolicy.DESTROY,
        )

        lambda_layer = aws_lambda.LayerVersion(
            scope=self,
            id="lambda_layer",
            layer_version_name=f"{lambda_name}_lambda_layer",
            compatible_runtimes=[aws_lambda.Runtime.PYTHON_3_8],
            code=aws_lambda.Code.from_asset(str(Path(cdk_config.build_path, "lambda", "output").absolute())),
            compatible_architectures=[aws_lambda.Architecture.ARM_64, aws_lambda.Architecture.X86_64],
            removal_policy=RemovalPolicy.DESTROY,
        )

        # https://aws-sdk-pandas.readthedocs.io/en/3.0.0/layers.html
        aws_data_wrangeler_layer = aws_lambda.LayerVersion.from_layer_version_arn(
            self,
            "aws-data-wrangeler-layer",
            f"arn:aws:lambda:{scope.region}:336392948345:layer:AWSSDKPandas-Python38-Arm64:7"
        )


        lambda_statements = [
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "kms:Decrypt",
                    "kms:Encrypt",
                    "kms:DescribeKey",
                    "kms:ReEncrypt*",
                    "kms:GenerateDataKey*",
                ],
                resources=[kms_key_s3.arn],
            ),
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                ],
                resources=[log_group.log_group_arn],
            ),
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=["s3:ListBucket"],
                resources=[
                    bucket_raw.arn,
                    bucket_gold.arn
                ],
            ),
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "s3:GetObject",
                    "s3:GetObjectAcl",
                    "s3:PutObject",
                    "s3:PutObjectAcl",
                    "s3:DeleteObject",
                ],
                resources=[
                    bucket_raw.this.arn_for_objects("*"),
                    bucket_gold.this.arn_for_objects("*")
                ],
            ),
        ]

        lambda_runtime_role = iam.Role(
            scope=self,
            id="lambda_runtime_role",
            role_name=f"CFM_Role_{lambda_name}_lambda_runtime_role",
            assumed_by=iam.ServicePrincipal("lambda.amazonaws.com"),
            inline_policies={"lambda": iam.PolicyDocument(statements=lambda_statements)},
        )

        lambda_runtime_role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("service-role/AWSLambdaVPCAccessExecutionRole")
        )

        # To be restricted.
        lambdas_security_group = ec2.SecurityGroup(
            scope=self,
            id="lambda_security_group",
            security_group_name=f"{cdk_config.application_name}-lambda",
            description="Access of S3 from MS Primebrokerage Lambda",
            vpc=vpc,
            allow_all_outbound=True,
        )
        public_subnets_selection = ec2.SubnetSelection(subnets=public_subnets)

        self.app = aws_lambda.Function(
            scope=self,
            id="lambda",
            function_name=lambda_name,
            runtime=aws_lambda.Runtime.PYTHON_3_8,
            code=aws_lambda.Code.from_asset(str(Path(cdk_config.src_path, "lambda").absolute())),
            handler="main.lambda_handler",
            timeout=Duration.minutes(15),
            memory_size=512,
            architecture=aws_lambda.Architecture.ARM_64,
            role=lambda_runtime_role,
            layers=[lambda_layer, aws_data_wrangeler_layer],
            vpc=vpc,
            vpc_subnets=public_subnets_selection,
            environment={"APP_PACKAGE": cdk_config.app_package_name},
            environment_encryption=None,
            security_groups=[lambdas_security_group],
        )
